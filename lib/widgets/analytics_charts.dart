import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme.dart';

class TestBreakdownChart extends StatelessWidget {
  final Map<String, int> breakdown;
  final String testName;

  const TestBreakdownChart({
    super.key,
    required this.breakdown,
    required this.testName,
  });

  Color _getColorForLabel(String label) {
    final clean = label.toLowerCase();
    if (clean.contains('normal') || clean.contains('negative') || clean.contains('uninfected')) {
      return AppColors.successGreen;
    }
    if (clean.contains('elevated') || clean.contains('high') || clean.contains('positive')) {
      return AppColors.dangerRed;
    }
    if (clean.contains('low')) {
      return AppColors.infoBlue;
    }
    if (clean.contains('moderate') || clean.contains('interm')) {
      return AppColors.warningAmber;
    }
    if (clean.contains('undetectable')) {
      return Colors.teal;
    }

    // Default colors for generic/other categories
    final List<Color> genericColors = [
      AppColors.accentIndigo,
      Colors.purple,
      Colors.cyan,
      Colors.orange,
      Colors.pink,
    ];
    
    // Hash key to select color consistently
    final int hash = label.hashCode.abs();
    return genericColors[hash % genericColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final total = breakdown.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No test result data available.')),
      );
    }

    // Convert data to PieChartSectionData
    final List<PieChartSectionData> sections = [];
    breakdown.forEach((label, count) {
      if (count > 0) {
        final double percentage = (count / total) * 100;
        sections.add(
          PieChartSectionData(
            color: _getColorForLabel(label),
            value: count.toDouble(),
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    return Column(
      children: [
        // The Pie Chart
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sections,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Legends
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: breakdown.entries.where((entry) => entry.value > 0).map((entry) {
            final label = entry.key;
            final count = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getColorForLabel(label),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$label ($count)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
