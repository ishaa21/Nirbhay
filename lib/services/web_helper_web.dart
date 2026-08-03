// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void removeSplash() {
  final progressBar = html.document.getElementById('web-progress-bar');
  if (progressBar != null) {
    progressBar.style.width = '100%';
  }

  final element = html.document.getElementById('splash-overlay');
  if (element != null) {
    element.style.transition = 'opacity 0.5s ease-out';
    element.style.opacity = '0';
    Future.delayed(const Duration(milliseconds: 500), () {
      element.remove();
    });
  }
}

