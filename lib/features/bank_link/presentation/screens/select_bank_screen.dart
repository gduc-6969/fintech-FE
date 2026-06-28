import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class SelectBankScreen extends StatefulWidget {
  final List<String> linkedBankCodes;

  const SelectBankScreen({super.key, this.linkedBankCodes = const []});

  @override
  State<SelectBankScreen> createState() => _SelectBankScreenState();
}

class _SelectBankScreenState extends State<SelectBankScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  
  final List<Map<String, dynamic>> _supportedBanks = [
    {
      'id': '1',
      'code': 'VCB',
      'name': 'Vietcombank',
      'color': const Color(0xFF007B40),
      'isLinked': true,
    },
    {
      'id': '2',
      'code': 'TCB',
      'name': 'Techcombank',
      'color': const Color(0xFFCC0000),
      'isLinked': true,
    },
    {
      'id': '3',
      'code': 'MB',
      'name': 'MBBank',
      'color': const Color(0xFF1B4E9B),
      'isLinked': false,
    },
    {
      'id': '4',
      'code': 'BIDV',
      'name': 'BIDV',
      'color': const Color(0xFF0D5A86),
      'isLinked': false,
    },
    {
      'id': '5',
      'code': 'ACB',
      'name': 'ACB',
      'color': const Color(0xFF005DAA),
      'isLinked': false,
    },
    {
      'id': '6',
      'code': 'VPB',
      'name': 'VPBank',
      'color': const Color(0xFF00A651),
      'isLinked': false,
    },
  ];

  List<Map<String, dynamic>> _filteredBanks = [];
  bool _isLoading = true;
  List<String> _activeBankCodes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadData() async {
    try {
      final activeCodes = await ApiService.getTopUpMethods();
      if (mounted) {
        setState(() {
          _activeBankCodes = activeCodes.map((c) => c.toUpperCase()).toList();
          for (var i = 0; i < _supportedBanks.length; i++) {
            final code = _supportedBanks[i]['code'] as String;
            _supportedBanks[i]['isLinked'] = widget.linkedBankCodes.contains(code);
            _supportedBanks[i]['isSupported'] = _activeBankCodes.isEmpty || _activeBankCodes.contains(code.toUpperCase());
          }
          _filteredBanks = List.from(_supportedBanks);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          for (var i = 0; i < _supportedBanks.length; i++) {
            final code = _supportedBanks[i]['code'] as String;
            _supportedBanks[i]['isLinked'] = widget.linkedBankCodes.contains(code);
            _supportedBanks[i]['isSupported'] = true; // Fallback to all supported
          }
          _filteredBanks = List.from(_supportedBanks);
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredBanks = _supportedBanks.where((bank) {
        return bank['name'].toString().toLowerCase().contains(query) ||
               bank['code'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Chọn ngân hàng', style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : Column(
              children: [
                // Search Field
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm ngân hàng...',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                // Bank List
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredBanks.length,
                    itemBuilder: (context, index) {
                      final bank = _filteredBanks[index];
                      final isLinked = bank['isLinked'] == true;
                      final isSupported = bank['isSupported'] ?? true;
                      final isSelectable = !isLinked && isSupported;
                      
                      return InkWell(
                        onTap: isSelectable ? () {
                          context.push('/account-details', extra: bank);
                        } : null,
                        child: Opacity(
                          opacity: isSelectable ? 1.0 : 0.5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelectable ? bank['color'] : AppColors.textSecondary.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(bank['code'], style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    bank['name'],
                                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ),
                                if (isLinked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.inputFill,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('ĐÃ LIÊN KẾT', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                  )
                                else if (!isSupported)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('CHƯA HỖ TRỢ', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
