#!/usr/bin/env node
// Live multi-session security check against a real Supabase project.
//
//   node tool/live_security_check.mjs                 # reads env/dev.json
//   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... node tool/live_security_check.mjs
//
// Uses only the public (publishable/anon) key, exactly like the web app, with
// four separate anonymous users: host, guest, stranger and a second host. It
// creates two short-lived rooms and closes them at the end. Exit code 1 if any
// check fails. Requires Node 22+ (global fetch and WebSocket).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
let URL_ = process.env.SUPABASE_URL;
let KEY = process.env.SUPABASE_PUBLISHABLE_KEY;
if (!URL_ || !KEY) {
  const cfg = JSON.parse(readFileSync(join(root, 'env/dev.json'), 'utf8'));
  URL_ ??= cfg.SUPABASE_URL;
  KEY ??= cfg.SUPABASE_PUBLISHABLE_KEY;
}

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok: !!ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `  [${detail}]`}`);
};

async function http(path, { method = 'POST', body, token } = {}) {
  const headers = { apikey: KEY, 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(URL_ + path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  return { status: res.status, json };
}
const rpc = (name, args, token) => http(`/rest/v1/rpc/${name}`, { body: args, token });
const select = (table, qs, token) => http(`/rest/v1/${table}?${qs}`, { method: 'GET', token });
const msg = (r) => (r.json && (r.json.message || r.json.msg)) || JSON.stringify(r.json);
const failedWith = (r, fragment) => r.status >= 400 && String(msg(r)).includes(fragment);

async function newUser() {
  const r = await http('/auth/v1/signup', { body: {} });
  if (!r.json?.access_token) throw new Error(`anonymous sign-in failed: ${JSON.stringify(r.json)}`);
  return { token: r.json.access_token, id: r.json.user.id };
}

// Phoenix-protocol probe: can this user join the room's private presence channel?
async function canJoinPresence(token, roomId) {
  return new Promise((resolve) => {
    const ws = new WebSocket(
      `${URL_.replace('https', 'wss')}/realtime/v1/websocket?apikey=${KEY}&vsn=1.0.0`,
    );
    let verdict = null;
    const finish = (v, why) => { if (verdict === null) { verdict = v; try { ws.close(); } catch {} resolve({ ok: v, why }); } };
    const timer = setTimeout(() => finish(joined, 'timeout'), 6000);
    let joined = false;
    ws.onopen = () => ws.send(JSON.stringify({
      topic: `realtime:room:${roomId}`, event: 'phx_join', ref: '1', join_ref: '1',
      // presence.enabled must be set or Realtime refuses everyone (even members),
      // which would make the "stranger is refused" check meaningless.
      payload: { config: { private: true, presence: { key: 'probe', enabled: true }, broadcast: { self: false, ack: false }, postgres_changes: [] }, access_token: token },
    }));
    ws.onmessage = (ev) => {
      let m; try { m = JSON.parse(ev.data); } catch { return; }
      if (m.event === 'phx_reply' && m.ref === '1') {
        if (m.payload?.status === 'ok') {
          joined = true;
          // Authorization errors can arrive just after an "ok": wait briefly.
          setTimeout(() => { clearTimeout(timer); finish(joined, 'joined'); }, 2500);
        } else finish(false, JSON.stringify(m.payload?.response ?? m.payload));
      }
      if (m.event === 'system' && m.payload?.status === 'error') {
        joined = false; clearTimeout(timer); finish(false, m.payload.message ?? 'system error');
      }
      if (m.event === 'phx_error' || m.event === 'phx_close') { clearTimeout(timer); finish(false, m.event); }
    };
    ws.onerror = () => { clearTimeout(timer); finish(false, 'ws error'); };
  });
}

const song = (rid, id, extra = {}) => ({
  p_room_id: rid, p_provider: 'mock', p_provider_song_id: id,
  p_title: 'Sec Test', p_artist: 'Artist', ...extra,
});

async function main() {
  console.log(`Target: ${URL_}\n`);
  const H = await newUser(), G = await newUser(), S = await newUser(), H2 = await newUser();

  // ---- unauthenticated (anon role) ------------------------------------------
  let r = await rpc('create_room', { p_room_name: 'x', p_description: null, p_host_name: 'x' });
  check('anon cannot create rooms', failedWith(r, 'permission denied'), msg(r));
  r = await select('rooms', 'select=id');
  check('anon reads no rooms', r.status === 200 ? (r.json ?? []).length === 0 : r.status >= 400, msg(r));

  // ---- room lifecycle --------------------------------------------------------
  r = await rpc('create_room', { p_room_name: 'Sec Room', p_description: null, p_host_name: 'Host', p_enable_voting: true }, H.token);
  check('host creates a room', r.status === 200 && r.json?.participant?.role === 'host', msg(r));
  const room = r.json.room, rid = room.id, code = room.room_code;
  check('room code is 10 random hex chars', /^[0-9A-F]{10}$/.test(code), code);

  r = await rpc('join_room', { p_code: code, p_display_name: 'Guest' }, G.token);
  check('guest joins as guest', r.status === 200 && r.json?.participant?.role === 'guest', msg(r));

  // ---- isolation --------------------------------------------------------------
  r = await select('rooms', `id=eq.${rid}&select=id`, S.token);
  check('stranger cannot read the room', r.status === 200 && r.json.length === 0, msg(r));
  r = await select('participants', `room_id=eq.${rid}&select=id`, S.token);
  check('stranger cannot read participants', r.status === 200 && r.json.length === 0, msg(r));
  r = await rpc('recommend_song', song(rid, 'demo-001'), S.token);
  check('stranger cannot recommend', failedWith(r, 'forbidden'), msg(r));
  r = await rpc('get_room_preview', { p_code: code }, S.token);
  check('stranger can preview by code (code is the capability)', r.status === 200 && r.json?.room_name === 'Sec Room', msg(r));

  // ---- direct writes are impossible (guest and host) ---------------------------
  for (const [who, tok] of [['guest', G.token], ['host', H.token]]) {
    r = await http(`/rest/v1/queue`, { body: { room_id: rid, song_id: rid, position: 0 }, token: tok });
    check(`${who} cannot INSERT into queue`, r.status >= 400, msg(r));
    r = await http(`/rest/v1/rooms?id=eq.${rid}`, { method: 'PATCH', body: { playback_status: 'playing', room_name: 'PWNED' }, token: tok });
    const after = await select('rooms', `id=eq.${rid}&select=room_name,playback_status`, H.token);
    check(`${who} cannot UPDATE rooms directly`, after.json?.[0]?.room_name === 'Sec Room' && after.json?.[0]?.playback_status === 'stopped', JSON.stringify(after.json));
    r = await http(`/rest/v1/participants?room_id=eq.${rid}`, { method: 'DELETE', token: tok });
    const parts = await select('participants', `room_id=eq.${rid}&select=id`, H.token);
    check(`${who} cannot DELETE participants directly`, parts.json?.length === 2, JSON.stringify(parts.json));
  }

  // ---- input validation (migration 5) -----------------------------------------
  r = await rpc('recommend_song', song(rid, 'bad-1', { p_artwork_url: 'javascript:alert(1)' }), G.token);
  check('javascript: artwork URL rejected', failedWith(r, 'invalid_song'), msg(r));
  r = await rpc('recommend_song', song(rid, 'bad-2', { p_artwork_url: 'http://tracker.example/p.png' }), G.token);
  check('non-https artwork URL rejected', failedWith(r, 'invalid_song'), msg(r));
  r = await rpc('recommend_song', song(rid, 'bad-3', { p_title: 'x'.repeat(201) }), G.token);
  check('201-char title rejected', failedWith(r, 'invalid_song'), msg(r));
  r = await rpc('recommend_song', song(rid, 'bad-4', { p_duration_ms: 99999999999 }), G.token);
  check('absurd duration rejected', failedWith(r, 'invalid_song'), msg(r));
  r = await rpc('create_room', { p_room_name: 'bad\u0001name', p_description: null, p_host_name: 'x' }, H2.token);
  check('control characters in a room name rejected', failedWith(r, 'invalid_room_name'), msg(r));

  // ---- guest restrictions ------------------------------------------------------
  r = await rpc('recommend_song', song(rid, 'demo-001', { p_title: 'Neon Skyline (Demo)' }), G.token);
  check('guest recommends a valid song', r.status === 200 && r.json?.status === 'pending', msg(r));
  const rec = r.json?.id;
  for (const [name, fn, args] of [
    ['review_recommendation', 'review_recommendation', { p_recommendation_id: rec, p_approve: true }],
    ['set_playback', 'set_playback', { p_room_id: rid, p_status: 'playing', p_position_ms: 0 }],
    ['play_next', 'play_next', { p_room_id: rid, p_expected_version: 0 }],
    ['close_room', 'close_room', { p_room_id: rid }],
  ]) {
    for (const [who, tok] of [['guest', G.token], ['stranger', S.token]]) {
      r = await rpc(fn, args, tok);
      check(`${who} cannot call ${name}`, failedWith(r, 'forbidden'), msg(r));
    }
  }

  // ---- host flow + duplicate-transition guard ----------------------------------
  r = await rpc('review_recommendation', { p_recommendation_id: rec, p_approve: true }, H.token);
  check('host approves the recommendation', r.status === 200 && r.json?.status === 'approved', msg(r));
  r = await select('queue', `room_id=eq.${rid}&select=position,status`, G.token);
  check('guest sees the queued song at position 0', r.json?.length === 1 && r.json[0].position === 0, JSON.stringify(r.json));
  r = await rpc('play_next', { p_room_id: rid, p_expected_version: 0 }, H.token);
  check('host starts playback with the current version', r.status === 200 && r.json?.playback_status === 'playing', msg(r));
  r = await rpc('play_next', { p_room_id: rid, p_expected_version: 0 }, H.token);
  check('duplicate play_next (stale version) rejected', failedWith(r, 'stale_playback_version'), msg(r));
  r = await rpc('set_playback', { p_room_id: rid, p_status: 'paused', p_position_ms: 86400001 }, H.token);
  check('position beyond 24h rejected', failedWith(r, 'invalid_playback'), msg(r));
  r = await select('rooms', `id=eq.${rid}&select=playback_status,playback_version`, G.token);
  check('guest sees playback state', r.json?.[0]?.playback_status === 'playing', JSON.stringify(r.json));

  // ---- songs isolated per room (metadata poisoning) ----------------------------
  r = await rpc('create_room', { p_room_name: 'Other Room', p_description: null, p_host_name: 'Host2' }, H2.token);
  const rid2 = r.json?.room?.id, code2 = r.json?.room?.room_code;
  r = await rpc('join_room', { p_code: code2, p_display_name: 'Victim' }, S.token);
  r = await rpc('recommend_song', song(rid2, 'demo-001', { p_title: 'Neon Skyline (Demo)' }), S.token);
  r = await select('songs', `select=title,room_id`, S.token);
  check('a guest sees only songs of rooms they belong to', r.status === 200 && r.json.every((s) => s.room_id === rid2), JSON.stringify(r.json));
  r = await select('songs', `select=title`, G.token);
  check("room members cannot read another room's songs", r.json.every((s) => s.title !== 'Other'), JSON.stringify(r.json));

  // ---- Realtime private channel authorization ----------------------------------
  const member = await canJoinPresence(G.token, rid);
  check('room member can join the private presence channel', member.ok, member.why);
  const stranger = await canJoinPresence(S.token, rid);
  check('stranger is refused on the private presence channel', stranger.ok === false, stranger.why);

  // ---- cleanup ----------------------------------------------------------------
  r = await rpc('close_room', { p_room_id: rid }, H.token);
  check('host closes the room', r.status < 300, msg(r));
  await rpc('close_room', { p_room_id: rid2 }, H2.token);
  r = await rpc('recommend_song', song(rid, 'demo-002'), G.token);
  check('closed room refuses recommendations', failedWith(r, 'room_closed'), msg(r));

  const failed = results.filter((x) => !x.ok);
  console.log(`\n${results.length} checks, ${failed.length} failed`);
  process.exit(failed.length ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(2); });
