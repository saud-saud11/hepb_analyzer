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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int testYear = selectedYear ?? patient.getLatestYear();
    final int age = patient.getAgeInYear(testYear);

    // Collect all test history entries as flat rows
    final List<Map<String, dynamic>> testRows = [];
    patient.testHistory.forEach((testName, yearMap) {
      yearMap.forEach((year, value) {
        testRows.add({
          'testName': testName,
          'year': year,
          'value': value,
        });
      });
    });

    // Sort by year descending, then test name
    testRows.sort((a, b) {
      final int yearComp = (b['year'] as int).compareTo(a['year'] as int);
      if (yearComp != 0) return yearComp;
      return (a['testName'] as String).compareTo(b['testName'] as String);
    });

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
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
                    'Patient Details',
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

          // Title
          Text(
            'Test History & Results',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),

          // History List
          Expanded(
            child: testRows.isEmpty
                ? const Center(child: Text('No test records found.'))
                : ListView.builder(
                    itemCount: testRows.length,
                    itemBuilder: (context, idx) {
                      final row = testRows[idx];
                      final tName = row['testName'] as String;
                      final tYear = row['year'] as int;
                      final tVal = row['value'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Year: $tYear',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                tVal.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? AppColors.primaryTealLight : AppColors.primaryTeal,
                                ),
                              ),
                            ],
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
