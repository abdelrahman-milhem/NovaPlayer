import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'app_localizations.dart';

import 'package:flutter/services.dart';
import '../services/vault_service.dart';

class AuthHelper {
  static final LocalAuthentication auth = LocalAuthentication();
  static const MethodChannel _channel = MethodChannel('com.zenora.app/apps');

  static Future<bool> authenticate(BuildContext context, String reason) async {
    try {
      bool didAuthenticate = await auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
      
      if (!didAuthenticate) {
        return await _showPinFallbackDialog(context);
      }
      VaultService.isDecoyMode = false;
      return true;
    } catch (e) {
      return await _showPinFallbackDialog(context);
    }
  }

  static Future<bool> _showPinFallbackDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPin = prefs.getString('auth_pin_fallback');
    String? decoyPin = prefs.getString('auth_pin_decoy');
    final lang = AppSettings.languageNotifier.value;
    
    if (savedPin == null || savedPin.isEmpty) {
      return false;
    }

    // احفظ مرجع الـ ScaffoldMessenger خارج الـ Dialog لتجنب مشكلة الـ context
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    TextEditingController pinController = TextEditingController();
    bool isSuccess = false;

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        String errorText = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(AppLocalizations.get('enter_pin', lang)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '****',
                      errorText: errorText.isEmpty ? null : errorText,
                    ),
                    onSubmitted: (_) {
                      // نفس منطق زر OK عند الضغط على Enter
                      final input = pinController.text;
                      if (input == savedPin) {
                        VaultService.isDecoyMode = false;
                        isSuccess = true;
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      } else if (decoyPin != null && decoyPin.isNotEmpty && input == decoyPin) {
                        VaultService.isDecoyMode = true;
                        isSuccess = true;
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      } else {
                        try { _channel.invokeMethod('captureIntruderSelfie'); } catch (_) {}
                        setDialogState(() {
                          errorText = AppLocalizations.get('wrong_pin', lang);
                          pinController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  },
                  child: Text(AppLocalizations.get('cancel', lang)),
                ),
                TextButton(
                  onPressed: () {
                    final input = pinController.text;
                    if (input == savedPin) {
                      VaultService.isDecoyMode = false;
                      isSuccess = true;
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    } else if (decoyPin != null && decoyPin.isNotEmpty && input == decoyPin) {
                      VaultService.isDecoyMode = true;
                      isSuccess = true;
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    } else {
                      // التقاط صورة للمتطفل
                      try { _channel.invokeMethod('captureIntruderSelfie'); } catch (_) {}
                      // تحديث رسالة الخطأ داخل الـ Dialog
                      setDialogState(() {
                        errorText = AppLocalizations.get('wrong_pin', lang);
                        pinController.clear();
                      });
                      // عرض SnackBar بالـ context الخارجي للـ Scaffold
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.get('wrong_pin', lang)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    return isSuccess;
  }

  static Future<bool> isLocked(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setLocked(String key, bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
