// Removes the loading splash once Flutter has drawn its first frame.
window.addEventListener('flutter-first-frame', function () {
  var splash = document.getElementById('splash');
  if (splash) splash.remove();
});
