import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class BankLinkSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> bank;
  const BankLinkSuccessScreen({super.key, required this.bank});

  @override
  State<BankLinkSuccessScreen> createState() => _BankLinkSuccessScreenState();
}

class _BankLinkSuccessScreenState extends State<BankLinkSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.elasticOut,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holder = widget.bank['holder']?.toString().trim();
    final holderName = holder == null || holder.isEmpty
        ? 'CHƯA XÁC ĐỊNH'
        : holder;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFDCFCE7).withOpacity(0.5),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Animated Check Icon
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 8,
                        )
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text('Đã liên kết ngân hàng!', style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                
                const SizedBox(height: 24),
                
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: widget.bank['color'], borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(widget.bank['code'], style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.bank['name'], style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(holderName, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to home/wallet, specifically to the Cards tab ideally.
                      // Since we are popping everything, context.go('/wallet') is best.
                      context.go('/wallet');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Về danh sách tài khoản', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
