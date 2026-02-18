import 'package:flutter/material.dart';
import '../../services/billing_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/premium_ui.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final BillingService _billing = BillingService();
  bool _isYearly = false;

  @override
  void initState() {
    super.initState();
    _billing.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _billing.restorePurchases();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Purchases restored')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Restore failed: $e')),
                );
              }
            },
            child: const Text(
              "Restore",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const PremiumBackground(child: SizedBox.shrink()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Upgrade to Pro",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Unlock the full power of SafeShell",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),

                  // Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToggleButton(
                          text: "Monthly",
                          isSelected: !_isYearly,
                          onTap: () => setState(() => _isYearly = false),
                        ),
                        _ToggleButton(
                          text: "Yearly (-17%)",
                          isSelected: _isYearly,
                          onTap: () => setState(() => _isYearly = true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Comparison Table
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _comparisonRow(
                          "Feature",
                          "Free",
                          "Pro",
                          isHeader: true,
                        ),
                        const Divider(color: Colors.white12),
                        _comparisonRow("Storage", "5 GB", "Unlimited"),
                        _comparisonRow("Ads", "Yes", "No (Ad-Free)"),
                        _comparisonRow("USB Protection", "Basic", "Advanced"),
                        _comparisonRow("Ghost Mode", "❌", "✅"),
                        _comparisonRow("Cloud Backup", "Manual", "Auto"),
                        _comparisonRow("Priority Support", "❌", "✅"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Price and CTA
                  Text(
                    _isYearly ? "\$99.99 / year" : "\$9.99 / month",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isYearly ? "You save \$20.00 per year" : "Cancel anytime",
                    style: TextStyle(
                      color:
                          _isYearly ? const Color(0xFF10B981) : Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  AnimatedBuilder(
                    animation: _billing,
                    builder: (context, _) {
                      if (_billing.isPro) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "You are a Pro user!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return PrimaryButton(
                        text: "Subscribe via Google Play",
                        icon: Icons.payment,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (_billing.products.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Loading store... please wait"),
                              ),
                            );
                            await _billing.init();
                          }

                          // Select correct product by ID based on toggle
                          final targetId = _isYearly
                              ? BillingService.proYearly
                              : BillingService.proMonthly;

                          final product = _billing.products
                              .where(
                                (p) => p.id == targetId,
                              )
                              .toList();

                          if (product.isNotEmpty) {
                            try {
                              await _billing.purchase(product.first);
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Purchase error: $e')),
                              );
                            }
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Product not found. Check internet connection.",
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Trust Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Secured by Google Play",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      // Visual representation of cards supported via Google Play
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "VISA",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "MC",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    String feature,
    String free,
    String pro, {
    bool isHeader = false,
  }) {
    final style = TextStyle(
      color: isHeader ? Colors.white : Colors.white70,
      fontWeight: isHeader ? FontWeight.w900 : FontWeight.normal,
      fontSize: isHeader ? 14 : 13,
    );
    final proStyle = TextStyle(
      color: isHeader ? const Color(0xFF4DA3FF) : const Color(0xFF4DA3FF),
      fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600,
      fontSize: isHeader ? 14 : 13,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(feature, style: style)),
          Expanded(flex: 1, child: Text(free, style: style)),
          Expanded(flex: 1, child: Text(pro, style: proStyle)),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4DA3FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
