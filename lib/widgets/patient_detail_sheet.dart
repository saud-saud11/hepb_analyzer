import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../utils/theme.dart';

class PatientDetailSheet extends StatelessWidget {
  final Patient patient;
  final int? selectedYear;

  const PatientDetailSheet({
    super.key,
    required this.patient,
    this.selectedYear,
  });

  Widget _buildMarkerChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatedScoreCard(
    BuildContext context, {
    required String title,
    required String score,
    required String level,
    required Color color,
    required String formula,
    required String interpretation,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'points',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Formula: $formula',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const Divider(height: 20),
          Text(
            interpretation,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _getClinicalRecommendations(HepBPhase phase, FibrosisRiskLevel risk) {
    if (risk == FibrosisRiskLevel.high) {
      return '⚠️ High Risk of Cirrhosis / Advanced Fibrosis:\n'
          '• Urgent referral to a gastroenterologist/hepatologist is highly recommended.\n'
          '• Screen for Hepatocellular Carcinoma (HCC) using abdominal ultrasound every 6 months.\n'
          '• Initiate antiviral therapy (e.g., Tenofovir Alafenamide or Entecavir) if HBV DNA is detectable, regardless of ALT levels.';
    }

    switch (phase) {
      case HepBPhase.activeHBeAgPositive:
      case HepBPhase.activeHBeAgNegative:
        return '🟢 Active Chronic Hepatitis B (Treatment Candidate):\n'
            '• Patient meets WHO/EASL eligibility criteria for antiviral therapy due to elevated ALT and active viral replication.\n'
            '• Standard first-line therapy: Tenofovir DF (TDF), Tenofovir Alafenamide (TAF), or Entecavir (ETV).\n'
            '• Check renal function (Creatinine Clearance) before prescribing TDF.\n'
            '• Follow up ALT and HBV DNA every 3 months until stable, then every 6 months.';
      
      case HepBPhase.immuneTolerant:
        return '🟡 HBeAg-Positive Chronic Infection (Immune Tolerant):\n'
            '• Antiviral therapy is generally not indicated immediately due to normal liver enzymes (ALT) and low risk of active fibrosis.\n'
            '• High viral load (>10^7 IU/mL) is expected in this phase.\n'
            '• Monitor liver enzymes (ALT) and HBV DNA levels every 3 to 6 months. If ALT becomes elevated, re-evaluate for treatment eligibility.\n'
            '• Re-evaluate fibrosis index (FIB-4) annually.';
      
      case HepBPhase.inactiveCarrier:
        return '🔵 HBeAg-Negative Chronic Infection (Inactive Carrier):\n'
            '• Low risk of disease progression. Antiviral treatment is not indicated.\n'
            '• Monitor ALT and HBV DNA every 6 to 12 months to detect potential reactivation (transition to Phase 4).\n'
            '• Educate patient on avoiding liver-damaging substances (alcohol, hepatotoxic medications).';
      
      case HepBPhase.resolved:
        return '⚪ Resolved HBV Infection:\n'
            '• HBsAg is negative. No monitoring or therapy is required for healthy individuals.\n'
            '• Warning: If the patient requires intensive immunosuppression or chemotherapy, there is a risk of HBV reactivation. Prophylactic antiviral therapy (Entecavir) should be considered during immunosuppressive therapy.';
      
      case HepBPhase.vaccinated:
        return '💉 Vaccinated / Immune:\n'
            '• Protected against Hepatitis B infection. No further action or follow-up needed.';
      
      case HepBPhase.susceptible:
        return '🔴 Susceptible (Uninfected):\n'
            '• Patient has no active infection and no immunity.\n'
            '• Action: Offer standard Hepatitis B vaccine series (3 doses at 0, 1, and 6 months).';
      
      case HepBPhase.indeterminate:
        return '🔍 Indeterminate clinical profile:\n'
            '• Clinical markers do not fit standard EASL phases perfectly.\n'
            '• Action: Repeat serology and liver panels in 3-6 months. Consider transient elastography (Fibroscan) to determine liver stiffness directly.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Core parameters
    final int testYear = selectedYear ?? patient.getLatestYear();
    final int age = patient.getAgeInYear(testYear);
    
    final hbsag = patient.getHbsag(testYear);
    final hbeag = patient.getHbeag(testYear);
    final dna = patient.getHbvDna(testYear);
    final alt = patient.getAlt(testYear);
    final ast = patient.getAst(testYear);
    final platelets = patient.getPlatelets(testYear);

    final fib4 = patient.getFib4(testYear);
    final apri = patient.getApri(testYear);
    final phase = patient.getDiseasePhase(testYear);
    final risk = patient.getFibrosisRisk(testYear);

    // Dynamic styling
    Color riskColor = AppColors.successGreen;
    if (risk == FibrosisRiskLevel.high) {
      riskColor = AppColors.dangerRed;
    } else if (risk == FibrosisRiskLevel.indeterminate) {
      riskColor = AppColors.warningAmber;
    } else if (risk == FibrosisRiskLevel.unknown) {
      riskColor = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar for Sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Patient Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Profile',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${patient.gender} • Age $age • Region: ${patient.region}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(height: 24),

            // Clinical Markers Grid
            Text(
              'Clinical Test Markers (Year: $testYear)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMarkerChip(
                  'HBsAg',
                  hbsag == null ? 'Not Done' : (hbsag ? 'Positive (+)' : 'Negative (-)'),
                  hbsag == true ? AppColors.dangerRed : AppColors.successGreen,
                ),
                _buildMarkerChip(
                  'HBeAg',
                  hbeag == null ? 'Not Done' : (hbeag ? 'Positive (+)' : 'Negative (-)'),
                  hbeag == true ? AppColors.dangerRed : AppColors.successGreen,
                ),
                _buildMarkerChip(
                  'HBV DNA (Viral Load)',
                  dna == null ? 'Not Done' : '${dna.toInt()} IU/mL',
                  dna != null && dna >= 2000 ? AppColors.warningAmber : AppColors.infoBlue,
                ),
                _buildMarkerChip(
                  'ALT (SGPT)',
                  alt == null ? 'Not Done' : '${alt.toInt()} U/L',
                  alt != null && alt > 40 ? AppColors.dangerRed : AppColors.successGreen,
                ),
                _buildMarkerChip(
                  'AST (SGOT)',
                  ast == null ? 'Not Done' : '${ast.toInt()} U/L',
                  ast != null && ast > 40 ? AppColors.dangerRed : AppColors.successGreen,
                ),
                _buildMarkerChip(
                  'Platelets (PLT)',
                  platelets == null ? 'Not Done' : '${platelets.toInt()} x10⁹/L',
                  platelets != null && platelets < 150 ? AppColors.warningAmber : AppColors.successGreen,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Staging Phase Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 32,
                    color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EASL Hepatitis B Phase',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phase.nameEn,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phase.nameAr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.primaryTealLight.withOpacity(0.8) : AppColors.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // FIB-4 & APRI Staging Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCalculatedScoreCard(
                    context,
                    title: 'FIB-4 Index',
                    score: fib4 == null ? 'N/A' : fib4.toString(),
                    level: risk.nameEn,
                    color: riskColor,
                    formula: '(Age * AST) / (Platelets * sqrt(ALT))',
                    interpretation: fib4 == null
                        ? 'Insufficient data (Age, AST, ALT, or Platelets missing).'
                        : fib4 < 1.45
                            ? 'FIB-4 < 1.45: Low risk of advanced liver fibrosis (90% negative predictive value).'
                            : fib4 > 3.25
                                ? 'FIB-4 > 3.25: High risk of advanced fibrosis (F3-F4) or cirrhosis.'
                                : 'FIB-4 between 1.45 and 3.25: Indeterminate risk. Consider transient elastography.',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCalculatedScoreCard(
                    context,
                    title: 'APRI Score',
                    score: apri == null ? 'N/A' : apri.toString(),
                    level: apri == null
                        ? 'N/A'
                        : apri > 1.5
                            ? 'Cirrhosis'
                            : apri > 0.5
                                ? 'Fibrosis'
                                : 'Normal',
                    color: apri == null
                        ? Colors.grey
                        : apri > 1.5
                            ? AppColors.dangerRed
                            : apri > 0.5
                                ? AppColors.warningAmber
                                : AppColors.successGreen,
                    formula: '((AST / 40.0) * 100) / Platelets',
                    interpretation: apri == null
                        ? 'Insufficient data (AST or Platelets missing).'
                        : apri > 1.5
                            ? 'APRI > 1.5: High probability of cirrhosis.'
                            : apri > 0.5
                                ? 'APRI > 0.5: Significant liver fibrosis predicted.'
                                : 'APRI <= 0.5: Low probability of significant fibrosis.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Clinical Guidelines Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_outlined, color: riskColor),
                      const SizedBox(width: 12),
                      Text(
                        'WHO / EASL Guideline Recommendations',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              color: riskColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getClinicalRecommendations(phase, risk),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
