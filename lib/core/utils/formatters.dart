abstract final class Formatters {
  /// 185000 -> "3:05"; null -> "--:--".
  static String duration(int? ms) {
    if (ms == null) return '--:--';
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String timeAgo(DateTime time, DateTime now) {
    final d = now.difference(time);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes == 0 ? 1 : d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
