import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'app_localizations.dart';

class AuthHelper {
  static final LocalAuthentication auth = LocalAuthentication();

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
      return true;
    } catch (e) {
      // Fallback if no biometric hardware or error occurs
      return await _showPinFallbackDialog(context);
    }
  }

  static Future<bool> _showPinFallbackDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPin = prefs.getString('auth_pin_fallback');
    
    if (savedPin == null || savedPin.isEmpty) {
      return false; // No PIN set, totally locked out
    }

    TextEditingController pinController = TextEditingController();
    bool isSuccess = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.get('enter_pin', AppSettings.languageNotifier.value)),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(hintText: '****'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // User canceled
              },
              child: Text(AppLocalizations.get('cancel', AppSettings.languageNotifier.value)),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text == savedPin) {
                  isSuccess = true;
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.get('wrong_pin', AppSettings.languageNotifier.value))),
                  );
                }
              },
              child: Text('OK'),
            ),
          ],
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
