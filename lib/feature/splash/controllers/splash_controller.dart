import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _initializeAppData();
  }

  Future<void> _initializeAppData() async {
    // Await any mandatory local storage/cache initialization here
    await Future.delayed(const Duration(milliseconds: 2200));

    // Replace '/home' with your actual primary route string
    Get.offAllNamed('/home');
  }
}