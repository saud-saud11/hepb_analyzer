import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analysis_provider.dart';
import '../models/patient_model.dart';
import '../utils/theme.dart';
import '../widgets/saudi_map.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/patient_detail_sheet.dart';

// PDF Export Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const DashboardScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedTest;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AnalysisProvider>(context, listen: false);
    if (provider.uniqueTestNames.isNotEmpty && _selectedTest == null) {
      // Default select the first test (e.g. ALT or HBsAg)
      _selectedTest = provider.uniqueTestNames.first;
    }
  }

  // Export current region and test statistics to a printable PDF
  Future<void> _exportPdfReport(BuildContext context, AnalysisProvider provider) async {
    final pdf = pw.Document();
    
    final int total = provider.totalPatientsCount;
    final int uniqueTests = provider.totalUniqueTestsCount;
    final int regionsCount = provider.totalRegionsCount;
    final List<Map<String, dynamic>> regionsTable = provider.regionAnalysisTable;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Hepatitis B Patient Registry Analysis Report',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text('Generated on: ${DateTime.now().toString().split('.').first}'),
                pw.Text('Source File: ${provider.fileName ?? "Local Database Cache"}'),
                pw.Divider(),
                
                pw.SizedBox(height: 16),
                pw.Text('1. Cohort Overview', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Bullet(text: 'Total Registry Patients: $total'),
                pw.Bullet(text: 'Unique Clinical Tests: $uniqueTests'),
                pw.Bullet(text: 'Saudi Regions Represented: $regionsCount'),

                pw.SizedBox(height: 20),
                pw.Text('2. Region Prevalence & Distribution', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                
                // Simplified Region Table for PDF
                pw.TableHelper.fromTextArray(
                  headers: ['Region', 'Population', 'Excel Patients', 'Prevalence', 'Cohort Share'],
                  data: regionsTable.map((row) {
                    final prevVal = row['prevalence'] as double;
                    final prevPer100k = prevVal * 1000; // cases per 100k
                    return [
                      row['region'].toString(),
                      row['population'].toString(),
                      row['patients'].toString(),
                      '${prevVal.toStringAsFixed(5)}% (${prevPer100k.toStringAsFixed(1)}/100k)',
                      '${row['cohortShare']}%',
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text('Confidential - Medical Research Registry Use Only', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'hepb_prevalence_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  void _showPatientDetails(BuildContext context, Patient patient, int? year) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.70,
        child: PatientDetailSheet(patient: patient, selectedYear: year),
      ),
    );
  }

  void _showDataEntryDialog(BuildContext context, AnalysisProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        String gender = 'Male';
        String region = 'Riyadh';
        String testSelect = 'ALT';
        final dobController = TextEditingController(text: '1990');
        final testNameController = TextEditingController(text: 'ALT');
        final yearController = TextEditingController(text: DateTime.now().year.toString());
        final valueController = TextEditingController();
        bool isCustomTest = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Patient Test Record / إدخال يدوي'),
              content: SingleChildScrollView(
                child: Form(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(labelText: 'Gender / الجنس'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                        ],
                        onChanged: (val) => setState(() => gender = val ?? 'Male'),
                      ),
                      const SizedBox(height: 12),
                      
                      // DOB Input
                      TextFormField(
                        controller: dobController,
                        decoration: const InputDecoration(labelText: 'DOB / سنة الميلاد (e.g. 1985)'),
                      ),
                      const SizedBox(height: 12),

                      // Region Dropdown
                      DropdownButtonFormField<String>(
                        value: region,
                        decoration: const InputDecoration(labelText: 'Region / المنطقة'),
                        items: Patient.saudiRegionPopulations.keys.map((reg) {
                          return DropdownMenuItem(value: reg, child: Text(reg));
                        }).toList(),
                        onChanged: (val) => setState(() => region = val ?? 'Riyadh'),
                      ),
                      const SizedBox(height: 12),

                      // Test Selection Dropdown
                      DropdownButtonFormField<String>(
                        value: testSelect,
                        decoration: const InputDecoration(labelText: 'Test Name / الفحص'),
                        items: const [
                          DropdownMenuItem(value: 'ALT', child: Text('ALT')),
                          DropdownMenuItem(value: 'AST', child: Text('AST')),
                          DropdownMenuItem(value: 'HBsAg', child: Text('HBsAg')),
                          DropdownMenuItem(value: 'Platelets', child: Text('Platelets')),
                          DropdownMenuItem(value: 'HBV DNA', child: Text('HBV DNA')),
                          DropdownMenuItem(value: 'Other', child: Text('Other (Enter Custom)...')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            testSelect = val ?? 'ALT';
                            isCustomTest = testSelect == 'Other';
                            if (!isCustomTest) {
                              testNameController.text = testSelect;
                            } else {
                              testNameController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Custom Test Name Input if "Other" selected
                      if (isCustomTest) ...[
                        TextFormField(
                          controller: testNameController,
                          decoration: const InputDecoration(labelText: 'Enter Test Name / اسم الفحص'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Result Year
                      TextFormField(
                        controller: yearController,
                        decoration: const InputDecoration(labelText: 'Result Year / السنة'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Result Value
                      TextFormField(
                        controller: valueController,
                        decoration: const InputDecoration(labelText: 'Result Value / النتيجة (e.g. 45, positive)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed: () {
                    final dob = dobController.text.trim();
                    final test = testNameController.text.trim();
                    final yearStr = yearController.text.trim();
                    final valStr = valueController.text.trim();

                    if (dob.isEmpty || test.isEmpty || yearStr.isEmpty || valStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields.')),
                      );
                      return;
                    }

                    final yr = int.tryParse(yearStr) ?? 2025;
                    provider.addManualRecord(
                      gender: gender,
                      dob: dob,
                      region: region,
                      testName: test,
                      year: yr,
                      value: valStr,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Record added successfully!')),
                    );
                  },
                  child: const Text('Add Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int? activeYear = provider.selectedYear != 'All' ? int.tryParse(provider.selectedYear) : null;

    if (provider.uniqueTestNames.isNotEmpty && _selectedTest == null) {
      _selectedTest = provider.uniqueTestNames.first;
    }

    // Get active test breakdown and stats
    final breakdown = _selectedTest != null 
        ? provider.getTestResultBreakdown(_selectedTest!, activeYear) 
        : <String, int>{};
        
    final stats = _selectedTest != null 
        ? provider.getTestNumericalStats(_selectedTest!, activeYear) 
        : <String, double>{};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hepatitis B Registry Dashboard'),
            if (provider.fileName != null)
              Text(
                'Source: ${provider.fileName}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          // Add Record Manually
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: AppColors.primaryTealLight),
            tooltip: 'Add Record / إدخال يدوي',
            onPressed: () => _showDataEntryDialog(context, provider),
          ),
          // Clear Cache
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
            tooltip: 'Clear Cache / Wipe Local Database',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Database Cache?'),
                  content: const Text('This will delete all patient records stored locally in your browser. You will need to upload your Excel file again.'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
                      onPressed: () {
                        provider.clearCache();
                        setState(() {
                          _selectedTest = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          // Export PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF Summary Report',
            onPressed: () => _exportPdfReport(context, provider),
          ),
          // Toggle Theme
          IconButton(
            icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Area - Interactive Map & Region analysis (Scrollable)
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Stats Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double cardWidth = (constraints.maxWidth - 32) / 3;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildStatCard(
                            context,
                            title: 'Registry Patients',
                            value: provider.totalPatientsCount.toString(),
                            subtitle: '${provider.malesCount} Males • ${provider.femalesCount} Females',
                            icon: Icons.people_outline,
                            color: AppColors.primaryTealLight,
                            width: cardWidth,
                          ),
                          _buildStatCard(
                            context,
                            title: 'Total Test Records',
                            value: provider.totalRecordsCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                            subtitle: '${provider.totalUniqueTestsCount} Clinical Markers Tracked',
                            icon: Icons.biotech_outlined,
                            color: AppColors.accentIndigo,
                            width: cardWidth,
                          ),
                          _buildStatCard(
                            context,
                            title: 'Regions Represented',
                            value: provider.totalRegionsCount.toString(),
                            subtitle: 'Out of 13 Saudi Regions',
                            icon: Icons.map_outlined,
                            color: AppColors.warningAmber,
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 2. Map & Region Table
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Saudi Arabia Region Distribution Map
                      Expanded(
                        flex: 11,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Geographic Registry Distribution',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'خريطة توزيع الحالات حسب مناطق المملكة وعرض الرقم',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (provider.selectedRegion != 'All')
                                      TextButton.icon(
                                        icon: const Icon(Icons.clear, size: 16),
                                        label: const Text('Reset Map Filter'),
                                        onPressed: () => provider.setRegionFilter('All'),
                                      ),
                                  ],
                                ),
                                const Divider(height: 24),
                                SaudiArabiaMap(
                                  patientCounts: provider.regionCounts,
                                  selectedRegion: provider.selectedRegion,
                                  onRegionSelected: provider.setRegionFilter,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Test Breakdown Chart
                      Expanded(
                        flex: 9,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test & Result Breakdown',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                ),
                                const Divider(height: 12),
                                // Test Selector Dropdown
                                if (provider.uniqueTestNames.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkCard : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedTest,
                                        isExpanded: true,
                                        hint: const Text('Select Clinical Test'),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedTest = val;
                                          });
                                        },
                                        items: provider.uniqueTestNames.map((test) {
                                          return DropdownMenuItem<String>(
                                            value: test,
                                            child: Text(test, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Stats display card if it has numeric values
                                  if (stats.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: (isDark ? AppColors.primaryTeal : AppColors.primaryTealLight).withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: (isDark ? AppColors.primaryTeal : AppColors.primaryTealLight).withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildMiniStats('Mean', stats['mean'].toString()),
                                          _buildMiniStats('Min', stats['min'].toString()),
                                          _buildMiniStats('Max', stats['max'].toString()),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  TestBreakdownChart(
                                    breakdown: breakdown,
                                    testName: _selectedTest ?? '',
                                  ),
                                ] else
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text('No test names found in dataset. Use manual entry or upload file to add records.'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2.5 Age Group Distribution Card
                  _buildAgeGroupAnalysis(context, provider),

                  const SizedBox(height: 20),

                  // 3. Region Analysis Prevalence Table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Region-wise Analysis & Prevalence',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'تحليل أعداد السجلات ونسبة الانتشار بناءً على الكثافة السكانية لكل منطقة',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          // Responsive Table
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.45),
                              child: DataTable(
                                horizontalMargin: 8,
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('Region / المنطقة', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Census Population / السكان', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Excel Patients / المرضى', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Prevalence / نسبة الانتشار', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Cohort Share / حصة الفئة', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: provider.regionAnalysisTable.map((row) {
                                  final double prevVal = row['prevalence'] as double;
                                  final double prevPer100k = prevVal * 1000; // cases per 100k
                                  final String prevStr = '${prevVal.toStringAsFixed(5)}% (${prevPer100k.toStringAsFixed(1)} per 100k)';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          row['region'].toString(),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataCell(Text(row['population'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'))),
                                      DataCell(Text(row['patients'].toString())),
                                      DataCell(
                                        Text(
                                          prevStr,
                                          style: TextStyle(
                                            color: prevVal > 0 ? AppColors.dangerRed : null,
                                            fontWeight: prevVal > 0 ? FontWeight.bold : null,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text('${row['cohortShare']}%')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vertical divider
          Container(width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

          // Right Sidebar - Virtualized Searchable Patient Registry List
          Expanded(
            flex: 3,
            child: Container(
              color: isDark ? AppColors.darkCard.withOpacity(0.3) : AppColors.lightCard.withOpacity(0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registry Records (${provider.patients.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  // Search Bar
                  TextField(
                    onChanged: provider.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search region, gender, age...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Filter Chips Row (Year & Gender)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterDropdown(
                          context,
                          label: 'Year',
                          value: provider.selectedYear,
                          options: provider.availableYears,
                          onChanged: (val) => provider.setYearFilter(val ?? 'All'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterDropdown(
                          context,
                          label: 'Gender',
                          value: provider.selectedGender,
                          options: const ['All', 'Male', 'Female'],
                          onChanged: (val) => provider.setGenderFilter(val ?? 'All'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),

                  // Virtualized list of patients
                  Expanded(
                    child: provider.patients.isEmpty
                        ? const Center(child: Text('No matching records.'))
                        : ListView.builder(
                            itemCount: provider.patients.length,
                            itemExtent: 64, // Fixed height for speed
                            itemBuilder: (context, idx) {
                              final p = provider.patients[idx];
                              final pYear = activeYear ?? p.getLatestYear();
                              final pAge = p.getAgeInYear(pYear);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _showPatientDetails(context, p, activeYear),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          p.gender.toLowerCase() == 'male' || p.gender.toLowerCase() == 'm' 
                                              ? Icons.male 
                                              : Icons.female,
                                          color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${p.gender} • Age $pAge',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                p.region,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, size: 16),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStats(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          hint: Text(label),
          onChanged: onChanged,
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(opt, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAgeGroupAnalysis(BuildContext context, AnalysisProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ageGroups = provider.ageGroupDistribution;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Age Group Distribution & Analysis',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'تحليل وتوزيع الحالات حسب الفئات العمرية والنسب المئوية والنوع الاجتماعي',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Age groups list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ageGroups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final group = ageGroups[index];
                final double percent = group['percentage'] as double;
                final int count = group['count'] as int;
                final int males = group['males'] as int;
                final int females = group['females'] as int;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          group['labelAr'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '$count patients (${percent.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent > 0 ? (percent / 100).clamp(0.0, 1.0) : 0.0,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                                  isDark ? AppColors.primaryTeal : AppColors.primaryTeal.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$males Males / ذكور  •  $females Females / إناث',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
