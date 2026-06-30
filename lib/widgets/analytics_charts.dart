import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/patient_model.dart';
import '../utils/theme.dart';

class PhasePieChart extends StatelessWidget {
  final Map<HepBPhase, int> phaseDistribution;

  const PhasePieChart({
    super.key,
    required this.phaseDistribution,
  });

  Color _getColorForPhase(HepBPhase phase) {
    switch (phase) {
      case HepBPhase.immuneTolerant:
        return AppColors.infoBlue;
      case HepBPhase.activeHBeAgPositive:
        return AppColors.dangerRed;
      case HepBPhase.inactiveCarrier:
        return AppColors.successGreen;
      case HepBPhase.activeHBeAgNegative:
        return AppColors.warningAmber;
      case HepBPhase.resolved:
        return Colors.teal;
      case HepBPhase.vaccinated:
        return Colors.purple;
      case HepBPhase.susceptible:
        return Colors.grey;
      case HepBPhase.indeterminate:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Sum total
    final total = phaseDistribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Center(child: Text('No data available'));
    }

    // Convert data to PieChartSectionData
    final List<PieChartSectionData> sections = [];
    phaseDistribution.forEach((phase, count) {
      if (count > 0) {
        final double percentage = (count / total) * 100;
        sections.add(
          PieChartSectionData(
            color: _getColorForPhase(phase),
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
          children: phaseDistribution.entries.where((entry) => entry.value > 0).map((entry) {
            final phase = entry.key;
            final count = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getColorForPhase(phase),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${phase.nameEn} ($count)',
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

class FibrosisBarChart extends StatelessWidget {
  final Map<FibrosisRiskLevel, int> fibrosisDistribution;

  const FibrosisBarChart({
    super.key,
    required this.fibrosisDistribution,
  });

  Color _getColorForRisk(FibrosisRiskLevel risk) {
    switch (risk) {
      case FibrosisRiskLevel.low:
        return AppColors.successGreen;
      case FibrosisRiskLevel.indeterminate:
        return AppColors.warningAmber;
      case FibrosisRiskLevel.high:
        return AppColors.dangerRed;
      case FibrosisRiskLevel.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find maximum count for scaling Y axis
    final maxCount = fibrosisDistribution.values.fold<int>(0, (max, val) => val > max ? val : max);
    final double maxY = maxCount == 0 ? 10.0 : (maxCount * 1.2).toDouble();

    // Map distribution to BarChartGroupData
    final List<BarChartGroupData> barGroups = [];
    int index = 0;
    
    // Define ordering
    final orderedRisks = [
      FibrosisRiskLevel.low,
      FibrosisRiskLevel.indeterminate,
      FibrosisRiskLevel.high,
      FibrosisRiskLevel.unknown,
    ];

    for (var risk in orderedRisks) {
      final count = fibrosisDistribution[risk] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: _getColorForRisk(risk),
              width: 24,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: isDark ? Colors.grey[800]?.withOpacity(0.2) : Colors.grey[200]?.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
      index++;
    }

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => isDark ? AppColors.darkCard : Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final risk = orderedRisks[group.x.toInt()];
                return BarTooltipItem(
                  '${risk.nameEn}\n',
                  TextStyle(
                    color: _getColorForRisk(risk),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: 'Patients: ${rod.toY.toInt()}',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final risk = orderedRisks[value.toInt()];
                  String label = '';
                  switch (risk) {
                    case FibrosisRiskLevel.low:
                      label = 'Low';
                      break;
                    case FibrosisRiskLevel.indeterminate:
                      label = 'Interm.';
                      break;
                    case FibrosisRiskLevel.high:
                      label = 'High';
                      break;
                    case FibrosisRiskLevel.unknown:
                      label = 'No Data';
                      break;
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? AppColors.darkBorder.withOpacity(0.3) : AppColors.lightBorder,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}
