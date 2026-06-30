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

class DashboardScreen extends StatelessWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const DashboardScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  // Export current summary statistics to a printable PDF document
  Future<void> _exportPdfReport(BuildContext context, AnalysisProvider provider) async {
    final pdf = pw.Document();
    
    final int total = provider.totalPatientsCount;
    final int males = provider.malesCount;
    final int females = provider.femalesCount;
    final double avgAlt = provider.averageAlt;
    final double avgAst = provider.averageAst;
    final double avgFib4 = provider.averageFib4;

    final phaseDist = provider.phaseDistribution;
    final fibrosisDist = provider.fibrosisDistribution;

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
                    'Hepatitis B Patient Registry Staging Report',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Generated on: ${DateTime.now().toString().split('.').first}'),
                pw.Text('Source File: ${provider.fileName ?? "Local Database Cache"}'),
                pw.Divider(),
                
                pw.SizedBox(height: 20),
                pw.Text('1. Executive Clinical Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Bullet(text: 'Total Active Patients: $total'),
                pw.Bullet(text: 'Gender Distribution: Males: $males, Females: $females'),
                pw.Bullet(text: 'Mean ALT Level: $avgAlt U/L'),
                pw.Bullet(text: 'Mean AST Level: $avgAst U/L'),
                pw.Bullet(text: 'Mean FIB-4 Score: $avgFib4 points'),

                pw.SizedBox(height: 20),
                pw.Text('2. EASL Disease Phase Distribution', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ...phaseDist.entries.map((entry) => 
                  pw.Text('• ${entry.key.nameEn}: ${entry.value} patients')
                ),

                pw.SizedBox(height: 20),
                pw.Text('3. Liver Fibrosis Risk Classification (FIB-4)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ...fibrosisDist.entries.map((entry) => 
                  pw.Text('• ${entry.key.nameEn}: ${entry.value} patients')
                ),
                
                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text('Confidential - Medical Research Use Only', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'hepb_registry_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  void _showPatientDetails(BuildContext context, Patient patient, int? year) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: PatientDetailSheet(patient: patient, selectedYear: year),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int? activeYear = provider.selectedYear != 'All' ? int.tryParse(provider.selectedYear) : null;

    // Calculate active hepatitis cases count (Phase 2 & Phase 4)
    final activeHepCount = provider.allPatients.where((p) {
      final phase = p.getDiseasePhase(activeYear);
      return phase == HepBPhase.activeHBeAgPositive || phase == HepBPhase.activeHBeAgNegative;
    }).length;

    // Calculate high fibrosis risk count
    final highFibrosisCount = provider.allPatients.where((p) {
      return p.getFibrosisRisk(activeYear) == FibrosisRiskLevel.high;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hepatitis B Dashboard'),
            if (provider.fileName != null)
              Text(
                'Source: ${provider.fileName}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
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
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar - Filters & SA Map (Scrollable)
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
                            title: 'Total Registry Patients',
                            value: provider.totalPatientsCount.toString(),
                            subtitle: '${provider.malesCount} Males • ${provider.femalesCount} Females',
                            icon: Icons.people_outline,
                            color: AppColors.primaryTealLight,
                            width: cardWidth,
                          ),
                          _buildStatCard(
                            context,
                            title: 'Active Hepatitis Cases',
                            value: activeHepCount.toString(),
                            subtitle: 'Eligible for Antivirals',
                            icon: Icons.healing_outlined,
                            color: AppColors.dangerRed,
                            width: cardWidth,
                          ),
                          _buildStatCard(
                            context,
                            title: 'High Fibrosis Risk',
                            value: highFibrosisCount.toString(),
                            subtitle: 'FIB-4 Score > 3.25',
                            icon: Icons.warning_amber_outlined,
                            color: AppColors.warningAmber,
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 2. Main Analytics Panel (Saudi Map + Charts)
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
                                          'خريطة توزيع الحالات حسب مناطق المملكة',
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

                      // Phase Pie Chart
                      Expanded(
                        flex: 9,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EASL Clinical Phase Distribution',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                ),
                                const Divider(height: 24),
                                PhasePieChart(phaseDistribution: provider.phaseDistribution),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Bottom Row (Fibrosis Bar Chart + Bio Markers Averages)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fibrosis Bar Chart
                      Expanded(
                        flex: 11,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Liver Fibrosis Risk Staging (FIB-4)',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                ),
                                const Divider(height: 24),
                                FibrosisBarChart(fibrosisDistribution: provider.fibrosisDistribution),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Bio Markers Average Stats
                      Expanded(
                        flex: 9,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mean Cohort Biomarkers',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                ),
                                const Divider(height: 24),
                                _buildBiomarkerTile(context, 'ALT (SGPT) level', '${provider.averageAlt} U/L', AppColors.primaryTealLight),
                                _buildBiomarkerTile(context, 'AST (SGOT) level', '${provider.averageAst} U/L', AppColors.accentIndigo),
                                _buildBiomarkerTile(context, 'Platelets (PLT) count', '${provider.averagePlatelets} x10⁹/L', AppColors.warningAmber),
                                _buildBiomarkerTile(context, 'Mean FIB-4 Score', '${provider.averageFib4} pts', AppColors.dangerRed),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

                  // Quick Filter Chips Row (Year)
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

                  // Virtualized list of patients (Supports 50k+ smoothly!)
                  Expanded(
                    child: provider.patients.isEmpty
                        ? const Center(child: Text('No matching records.'))
                        : ListView.builder(
                            itemCount: provider.patients.length,
                            itemExtent: 72, // Fixed height for speed optimization
                            itemBuilder: (context, idx) {
                              final p = provider.patients[idx];
                              final pYear = activeYear ?? p.getLatestYear();
                              final pAge = p.getAgeInYear(pYear);
                              final pPhase = p.getDiseasePhase(pYear);
                              final pRisk = p.getFibrosisRisk(pYear);
                              
                              Color riskDotColor = AppColors.successGreen;
                              if (pRisk == FibrosisRiskLevel.high) {
                                riskDotColor = AppColors.dangerRed;
                              } else if (pRisk == FibrosisRiskLevel.indeterminate) {
                                riskDotColor = AppColors.warningAmber;
                              } else if (pRisk == FibrosisRiskLevel.unknown) {
                                riskDotColor = Colors.grey;
                              }

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
                                        // Risk indicator dot
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: riskDotColor,
                                            shape: BoxShape.circle,
                                          ),
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
                                        // Stage abbreviation / indicator badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getPhaseAbbreviation(pPhase),
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
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

  String _getPhaseAbbreviation(HepBPhase phase) {
    switch (phase) {
      case HepBPhase.immuneTolerant:
        return 'Tolerant';
      case HepBPhase.activeHBeAgPositive:
        return 'Act. HBe+';
      case HepBPhase.inactiveCarrier:
        return 'Carrier';
      case HepBPhase.activeHBeAgNegative:
        return 'Act. HBe-';
      case HepBPhase.resolved:
        return 'Resolved';
      case HepBPhase.vaccinated:
        return 'Immune';
      case HepBPhase.susceptible:
        return 'Suscept.';
      case HepBPhase.indeterminate:
        return 'Indeterm.';
    }
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

  Widget _buildBiomarkerTile(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
}
