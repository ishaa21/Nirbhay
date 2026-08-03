import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart' as helper;

void removeWebSplash() {
  helper.removeSplash();
}
