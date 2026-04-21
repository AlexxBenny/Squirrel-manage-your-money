import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles biometric + device-credential auth (Android/iOS) and
/// falls back to a user-set 4-digit PIN stored in secure storage.
class AuthService {
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _pinKey = 'squirrel_clear_pin';

  /// Returns true if device supports biometric or device-credential auth.
  static Future<bool> get canUseBiometrics async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns true if user has set an app PIN.
  static Future<bool> get hasPinSet async {
    try {
      return (await _storage.read(key: _pinKey)) != null;
    } catch (_) {
      return false;
    }
  }

  /// Saves a 4-digit PIN to secure storage.
  static Future<void> setPin(String pin) async {
    try {
      await _storage.write(key: _pinKey, value: pin);
    } catch (_) {
      // Storage unavailable — PIN won't persist but session still works
    }
  }

  /// Returns true if provided PIN matches stored one.
  static Future<bool> verifyPin(String pin) async {
    try {
      final stored = await _storage.read(key: _pinKey);
      return stored == pin;
    } catch (_) {
      return false;
    }
  }

  /// Main auth gate — tries biometrics first, falls back to PIN.
  /// Returns true if authenticated.
  static Future<bool> authenticate(BuildContext context, {String reason = 'Confirm your identity'}) async {
    // Desktop / unsupported: go straight to PIN
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _pinFlow(context);
    }

    try {
      final canBio = await canUseBiometrics;
      if (canBio) {
        final result = await _auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: false,   // allows device PIN/pattern/password too
            stickyAuth: true,
          ),
        );
        if (result) return true;
      }
    } catch (_) {
      // local_auth unavailable or MissingPluginException — fall through to PIN
    }

    return _pinFlow(context);
  }

  static Future<bool> _pinFlow(BuildContext context) async {
    try {
      final hasPin = await hasPinSet;
      if (!hasPin) {
        return await _showSetPinDialog(context);
      }
      return _showVerifyPinDialog(context);
    } catch (_) {
      // Storage unavailable — show PIN dialog anyway (won't persist)
      return _showSetPinDialog(context);
    }
  }

  static Future<bool> _showSetPinDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(mode: _PinMode.setup),
    ) ?? false;
  }

  static Future<bool> _showVerifyPinDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PinDialog(mode: _PinMode.verify),
    ) ?? false;
  }
}

enum _PinMode { setup, verify }

class _PinDialog extends StatefulWidget {
  final _PinMode mode;
  const _PinDialog({required this.mode});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final List<String> _digits = [];
  List<String> _firstPin = [];
  bool _confirming = false;
  String? _error;
  bool _shaking = false;

  String get _display => List.generate(4, (i) => i < _digits.length ? '●' : '○').join('  ');

  String get _title {
    if (widget.mode == _PinMode.setup) {
      return _confirming ? 'Confirm PIN' : 'Set a 4-Digit PIN';
    }
    return 'Enter PIN';
  }

  String get _subtitle {
    if (widget.mode == _PinMode.setup) {
      return _confirming ? 'Re-enter your new PIN' : 'This PIN protects "Clear All Data"';
    }
    return 'Required to clear all data';
  }

  void _tap(String d) {
    if (_digits.length >= 4) return;
    setState(() { _digits.add(d); _error = null; });
    if (_digits.length == 4) _onComplete();
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _onComplete() async {
    final pin = _digits.join();

    if (widget.mode == _PinMode.setup) {
      if (!_confirming) {
        setState(() { _firstPin = List.from(_digits); _digits.clear(); _confirming = true; });
        return;
      }
      if (pin == _firstPin.join()) {
        await AuthService.setPin(pin);
        if (mounted) Navigator.pop(context, true);
      } else {
        _shake('PINs don\'t match. Try again.');
        setState(() { _confirming = false; _firstPin = []; });
      }
    } else {
      final ok = await AuthService.verifyPin(pin);
      if (ok) {
        if (mounted) Navigator.pop(context, true);
      } else {
        _shake('Wrong PIN. Try again.');
      }
    }
  }

  void _shake(String msg) {
    setState(() { _shaking = true; _error = msg; _digits.clear(); });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shaking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _shaking
            ? Matrix4.translationValues(8, 0, 0)
            : Matrix4.identity(),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Lock icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            Text(_title, style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(_subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // PIN dots
            Text(_display, style: const TextStyle(fontSize: 22, letterSpacing: 8, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            // Numpad
            ...[[1,2,3],[4,5,6],[7,8,9]].map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: row.map((n) =>
                _NumKey(label: '$n', onTap: () => _tap('$n'))).toList()),
            )),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              const SizedBox(width: 64), // spacer
              _NumKey(label: '0', onTap: () => _tap('0')),
              SizedBox(width: 64, height: 56, child: TextButton(
                onPressed: _backspace,
                child: const Icon(Icons.backspace_outlined, size: 20, color: Color(0xFF64748B)),
              )),
            ]),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      ),
    );
  }
}
