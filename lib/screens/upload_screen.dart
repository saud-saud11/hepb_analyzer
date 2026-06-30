import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/analysis_provider.dart';
import '../utils/theme.dart';
import 'package:universal_html/html.dart' as html;

class UploadScreen extends StatelessWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const UploadScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  Future<void> _pickFile(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true, // Crucial for Web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        
        if (bytes != null) {
          final provider = Provider.of<AnalysisProvider>(context, listen: false);
          await provider.parseFile(bytes, file.name, file.size);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file contents.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void _downloadTemplate() {
    // Generate a mock CSV template based on the user's specific columns
    final String csvContent =
        "gender,dateofbirth,region_en,test_name,result_year,result_value\n"
        "Male,1985-05-12,Riyadh,HBsAg,2025,positive\n"
        "Male,1985-05-12,Riyadh,ALT,2025,45\n"
        "Male,1985-05-12,Riyadh,AST,2025,38\n"
        "Male,1985-05-12,Riyadh,Platelets,2025,180000\n"
        "Male,1985-05-12,Riyadh,HBV DNA,2025,150\n"
        "Female,1990-09-21,Makkah,HBsAg,2025,positive\n"
        "Female,1990-09-21,Makkah,ALT,2025,85\n"
        "Female,1990-09-21,Makkah,AST,2025,60\n"
        "Female,1990-09-21,Makkah,Platelets,2025,110000\n"
        "Female,1990-09-21,Makkah,HBV DNA,2025,650000\n"
        "Male,1975-01-01,Eastern Province,HBsAg,2025,positive\n"
        "Male,1975-01-01,Eastern Province,ALT,2025,120\n"
        "Male,1975-01-01,Eastern Province,AST,2025,95\n"
        "Male,1975-01-01,Eastern Province,Platelets,2025,95000\n"
        "Male,1975-01-01,Eastern Province,HBV DNA,2025,12000000\n"
        "Female,1998-04-15,Asir,HBsAg,2025,negative\n"
        "Female,1998-04-15,Asir,Anti-HBs,2025,positive\n"
        "Female,1998-04-15,Asir,Anti-HBc,2025,false\n"
        "Male,1988-10-10,Madinah,HBsAg,2025,positive\n"
        "Male,1988-10-10,Madinah,ALT,2025,25\n"
        "Male,1988-10-10,Madinah,HBV DNA,2025,45\n"
        "Male,1988-10-10,Madinah,HBeAg,2025,negative";

    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "hepb_sample_template.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Medical Icon
                Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                ),
                const SizedBox(height: 24),
                
                // App Title
                Text(
                  'Hepatitis B Patient Data Analyzer',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  'محلل بيانات مرضى التهاب الكبد الوبائي ب',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload your patient registry CSV or Excel sheet to dynamically analyze test results and map geographic distribution across Saudi Arabia.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 40),

                // Upload Card / Box
                if (provider.isLoading) ...[
                  // Loading / Parsing state
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: AppTheme.glassBox(context),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          'Parsing patient rows...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: provider.parseProgress,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          color: AppColors.primaryTealLight,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(provider.parseProgress * 100).toInt()}% completed',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                ] else ...[
                  // Upload Dropzone UI
                  InkWell(
                    onTap: () => _pickFile(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? AppColors.darkCard.withOpacity(0.5) 
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 64,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Click to select File (.csv, .xlsx, .xls)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '(CSV format is recommended for large datasets >10,000 rows)',
                            style: TextStyle(fontSize: 12, color: AppColors.primaryTealLight, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expected Columns: gender, dateofbirth, region_en, test_name, result_year, result_value',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Error Banner
                  if (provider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.dangerRed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: AppColors.dangerRed),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Download Template Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download Sample CSV Template'),
                        onPressed: _downloadTemplate,
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
