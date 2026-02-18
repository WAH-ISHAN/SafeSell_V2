import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../security/app_lock_service.dart';
import '../../security/key_manager.dart';
import '../../services/audit_log_service.dart';
import '../../services/stealth_mode_service.dart';

/// Calculator stealth screen – fake calculator that opens vault on correct stealth PIN.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  final _auditLog = AuditLogService();
  final _stealthService = StealthModeService();
  bool _verifying = false;

  void _onButton(String label) async {
    if (label == '=') {
      final inputCode = '$_expression=';

      // Check if PIN is set
      final hasPinSet = await _stealthService.hasStealthPinSet();
      if (!hasPinSet) {
        setState(() {
          _display = 'Error';
          _expression = '';
        });
        return;
      }

      // Verify the stealth PIN
      final verified = await _stealthService.verifyStealthPin(inputCode);
      if (verified) {
        await _auditLog.log(
          type: 'stealth_unlock',
          details: {'action': 'stealth_pin_correct'},
        );
        // Stealth PIN correct — now unlock the vault with the app-lock PIN
        if (mounted) {
          await _askVaultPin();
        }
        return;
      } else {
        // Wrong PIN - show a plausible calculation result
        setState(() {
          _display = _simpleEval(_expression);
          _expression = '';
        });
        return;
      }
    }

    // All other buttons - synchronous
    setState(() {
      if (label == 'C') {
        _display = '0';
        _expression = '';
      } else if (label == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _display = _expression.isEmpty ? '0' : _expression;
        }
      } else {
        if (_display == '0' && label != '.') {
          _expression = label;
        } else {
          _expression += label;
        }
        _display = _expression;
      }
    });
  }

  /// Show a discreet PIN dialog to unlock the vault key.
  /// On success navigate to dashboard. On failure show subtle error.
  Future<void> _askVaultPin() async {
    if (!mounted) return;
    final pinController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Enter App PIN',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'PIN',
                      hintStyle: const TextStyle(color: Colors.white38),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF9500)),
                      ),
                      errorText: errorText,
                      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: _verifying
                      ? null
                      : () async {
                          final pin = pinController.text.trim();
                          if (pin.isEmpty) return;

                          setDialogState(() => _verifying = true);
                          final appLockService = AppLockService();
                          final pinOk = await appLockService.verifyPin(pin);
                          if (pinOk) {
                            final unlocked = await KeyManager().unlock(pin);
                            if (unlocked) {
                              await _auditLog.log(
                                type: 'stealth_unlock',
                                details: {'action': 'vault_opened_from_calculator'},
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                              if (mounted) context.go('/dashboard');
                              return;
                            }
                          }
                          setDialogState(() {
                            _verifying = false;
                            errorText = 'Incorrect PIN';
                          });
                          pinController.clear();
                        },
                  child: const Text('Unlock', style: TextStyle(color: Color(0xFFFF9500))),
                ),
              ],
            );
          },
        );
      },
    );
    pinController.dispose();
    setState(() => _verifying = false);
  }

  String _simpleEval(String expr) {
    try {
      final parts = expr.split(RegExp(r'[+\-×÷]'));
      if (parts.length == 2) {
        final a = double.tryParse(parts[0]) ?? 0;
        final b = double.tryParse(parts[1]) ?? 0;
        if (expr.contains('+')) return '${a + b}';
        if (expr.contains('-')) return '${a - b}';
        if (expr.contains('×')) return '${a * b}';
        if (expr.contains('÷') && b != 0) return '${a / b}';
      }
      return expr;
    } catch (_) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            // Display
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(24),
                child: Text(
                  _display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Buttons
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildRow(['C', '⌫', '%', '÷']),
                    _buildRow(['7', '8', '9', '×']),
                    _buildRow(['4', '5', '6', '-']),
                    _buildRow(['1', '2', '3', '+']),
                    _buildRow(['00', '0', '.', '=']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> labels) {
    return Expanded(
      child: Row(
        children: labels.map((l) => Expanded(child: _calcButton(l))).toList(),
      ),
    );
  }

  Widget _calcButton(String label) {
    final isOp = ['÷', '×', '-', '+', '='].contains(label);
    final isTop = ['C', '⌫', '%'].contains(label);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: isOp
            ? const Color(0xFFFF9500)
            : isTop
                ? const Color(0xFF505050)
                : const Color(0xFF333333),
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => _onButton(label),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isOp ? 28 : 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
