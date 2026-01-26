import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_service.dart';
import '../utils/app_logger.dart';

class ExportDataBottomSheet extends StatefulWidget {
  const ExportDataBottomSheet({super.key});

  @override
  State<ExportDataBottomSheet> createState() => _ExportDataBottomSheetState();
}

class _ExportDataBottomSheetState extends State<ExportDataBottomSheet> {
  String? _selectedFormat;
  int _selectedDays = 30; // Default: 30 days (only 7, 14, or 30 allowed)
  bool _isExporting = false;
  final GlobalKey _exportButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedFormat = null; // User must select
  }

  Future<void> _exportData() async {
    if (_selectedFormat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a format')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final now = DateTime.now();
      // Only allow 7, 14, or 30 days
      int days = _selectedDays;
      if (days != 7 && days != 14 && days != 30) {
        days = 30; // Default to 30 if invalid
      }
      final startDate = now.subtract(Duration(days: days));
      final endDate = now;

      AppLogger.d('ExportDataBottomSheet',
          'Exporting: format=$_selectedFormat, days=$days');

      final file = await ExportService.exportData(
        format: _selectedFormat!,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      // Get share position origin from export button context (required for iPad)
      final RenderBox? box =
          _exportButtonKey.currentContext?.findRenderObject() as RenderBox?;
      Rect sharePositionOrigin;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
        // Ensure non-zero size
        if (sharePositionOrigin.width <= 0 || sharePositionOrigin.height <= 0) {
          sharePositionOrigin = const Rect.fromLTWH(0, 0, 1, 1);
        }
      } else {
        sharePositionOrigin = const Rect.fromLTWH(0, 0, 1, 1);
      }

      // Share single file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'NoteCal Data Export',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully')),
        );
      }
    } catch (e) {
      AppLogger.e('ExportDataBottomSheet', 'Error exporting data', e);
      // Only show error if file creation failed (not if share failed but file exists)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 28,
        right: 28,
        top: 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Export Data',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Format selection
          const Text(
            'Format',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFormatOption('CSV', 'csv'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormatOption('JSON', 'json'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Description text
          Text(
            'Export a clean summary for your dietitian.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 24),

          // Date range selection
          const Text(
            'Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Quick chips (7, 14, 30 days only)
          Row(
            children: [
              Expanded(child: _buildDaysChip(7)),
              const SizedBox(width: 8),
              Expanded(child: _buildDaysChip(14)),
              const SizedBox(width: 8),
              Expanded(child: _buildDaysChip(30)),
            ],
          ),

          const SizedBox(height: 32),

          // Export button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: _exportButtonKey,
              onPressed: _isExporting ? null : _exportData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: const Color(0xFF4A90E2),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isExporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String label, String value) {
    final isSelected = _selectedFormat == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A90E2).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF4A90E2) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysChip(int days) {
    final isSelected = _selectedDays == days;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDays = days;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A90E2).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          '$days days',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? const Color(0xFF4A90E2) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
