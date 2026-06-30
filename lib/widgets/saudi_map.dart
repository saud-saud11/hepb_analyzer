import 'package:flutter/material.dart';
import '../utils/theme.dart';

class RegionMapData {
  final String key;
  final String nameEn;
  final String nameAr;
  final double x; // Normalized 0.0 to 1.0
  final double y; // Normalized 0.0 to 1.0

  RegionMapData({
    required this.key,
    required this.nameEn,
    required this.nameAr,
    required this.x,
    required this.y,
  });
}

class SaudiArabiaMap extends StatefulWidget {
  final Map<String, int> patientCounts;
  final String selectedRegion;
  final Function(String) onRegionSelected;

  const SaudiArabiaMap({
    super.key,
    required this.patientCounts,
    required this.selectedRegion,
    required this.onRegionSelected,
  });

  @override
  State<SaudiArabiaMap> createState() => _SaudiArabiaMapState();
}

class _SaudiArabiaMapState extends State<SaudiArabiaMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  // 13 Regions of Saudi Arabia with their approximate relative positions on a map
  final List<RegionMapData> regions = [
    RegionMapData(key: 'riyadh', nameEn: 'Riyadh', nameAr: 'الرياض', x: 0.58, y: 0.54),
    RegionMapData(key: 'makkah', nameEn: 'Makkah', nameAr: 'مكة المكرمة', x: 0.32, y: 0.64),
    RegionMapData(key: 'madinah', nameEn: 'Madinah', nameAr: 'المدينة المنورة', x: 0.30, y: 0.46),
    RegionMapData(key: 'eastern', nameEn: 'Eastern Province', nameAr: 'المنطقة الشرقية', x: 0.76, y: 0.46),
    RegionMapData(key: 'qassim', nameEn: 'Al-Qassim', nameAr: 'القصيم', x: 0.48, y: 0.42),
    RegionMapData(key: 'hail', nameEn: 'Ha\'il', nameAr: 'حائل', x: 0.39, y: 0.33),
    RegionMapData(key: 'tabuk', nameEn: 'Tabuk', nameAr: 'تبوك', x: 0.18, y: 0.25),
    RegionMapData(key: 'jawf', nameEn: 'Al-Jawf', nameAr: 'الجوف', x: 0.29, y: 0.18),
    RegionMapData(key: 'borders', nameEn: 'Northern Borders', nameAr: 'الحدود الشمالية', x: 0.48, y: 0.16),
    RegionMapData(key: 'jazan', nameEn: 'Jazan', nameAr: 'جازان', x: 0.41, y: 0.88),
    RegionMapData(key: 'asir', nameEn: 'Asir', nameAr: 'عسير', x: 0.40, y: 0.78),
    RegionMapData(key: 'najran', nameEn: 'Najran', nameAr: 'نجران', x: 0.54, y: 0.81),
    RegionMapData(key: 'bahah', nameEn: 'Al-Bahah', nameAr: 'الباحة', x: 0.34, y: 0.72),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Helper to map dynamic excel string to region key
  String _normalizeRegion(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.contains('riyadh') || clean.contains('الرياض') || clean.contains('riyad')) return 'riyadh';
    if (clean.contains('makkah') || clean.contains('mecca') || clean.contains('مكة')) return 'makkah';
    if (clean.contains('madinah') || clean.contains('madina') || clean.contains('المدينة')) return 'madinah';
    if (clean.contains('eastern') || clean.contains('الشرقية') || clean.contains('dammam') || clean.contains('ahsa')) return 'eastern';
    if (clean.contains('qassim') || clean.contains('gassim') || clean.contains('القصيم')) return 'qassim';
    if (clean.contains('hail') || clean.contains('ha\'il') || clean.contains('حائل')) return 'hail';
    if (clean.contains('tabuk') || clean.contains('تبوك')) return 'tabuk';
    if (clean.contains('jawf') || clean.contains('الجوف')) return 'jawf';
    if (clean.contains('border') || clean.contains('شمالية') || clean.contains('arar')) return 'borders';
    if (clean.contains('jazan') || clean.contains('jizan') || clean.contains('جازان')) return 'jazan';
    if (clean.contains('asir') || clean.contains('aseer') || clean.contains('عسير') || clean.contains('abha')) return 'asir';
    if (clean.contains('najran') || clean.contains('نجران')) return 'najran';
    if (clean.contains('bahah') || clean.contains('الباحة')) return 'bahah';
    return '';
  }

  int _getCountForRegion(String key) {
    int count = 0;
    widget.patientCounts.forEach((regionName, val) {
      if (_normalizeRegion(regionName) == key) {
        count += val;
      }
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AspectRatio(
      aspectRatio: 1.3, // Matches Saudi shape aspect ratio
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. Background Country Outline
              Positioned.fill(
                child: CustomPaint(
                  painter: SaudiOutlinePainter(isDark: isDark),
                ),
              ),

              // 2. Interactive Badges for Regions
              ...regions.map((region) {
                final count = _getCountForRegion(region.key);
                final isSelected = widget.selectedRegion.toLowerCase() == region.nameEn.toLowerCase();
                
                // Position calculation based on normalized coordinates
                final left = region.x * constraints.maxWidth;
                final top = region.y * constraints.maxHeight;

                if (count == 0 && widget.selectedRegion != 'All') {
                  // Only hide if a region filter is active and this has 0
                  return const SizedBox.shrink();
                }

                return Positioned(
                  left: left - 24, // Shift left by half the size
                  top: top - 24, // Shift top by half the size
                  child: Tooltip(
                    richMessage: TextSpan(
                      children: [
                        TextSpan(
                          text: '${region.nameEn} (${region.nameAr})\n',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextSpan(
                          text: 'Patients: $count',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        // Toggle region filter on click
                        if (isSelected) {
                          widget.onRegionSelected('All');
                        } else {
                          widget.onRegionSelected(region.nameEn);
                        }
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final double pulseScale = count > 0 ? (1.0 + _pulseController.value * 0.15) : 1.0;
                          final double pulseOpacity = count > 0 ? (0.6 - _pulseController.value * 0.4) : 0.0;

                          return SizedBox(
                            width: 48,
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing pulsing ring for active regions
                                if (count > 0)
                                  Transform.scale(
                                    scale: pulseScale * 1.5,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected 
                                            ? AppColors.dangerRed.withOpacity(pulseOpacity)
                                            : AppColors.primaryTealLight.withOpacity(pulseOpacity),
                                      ),
                                    ),
                                  ),
                                
                                // Core Badge
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isSelected ? 36 : 28,
                                  height: isSelected ? 36 : 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected 
                                        ? AppColors.dangerRed 
                                        : (count > 0 ? AppColors.primaryTeal : Colors.grey[700]),
                                    border: Border.all(
                                      color: isDark ? Colors.white : Colors.black,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isSelected ? AppColors.dangerRed : AppColors.primaryTeal).withOpacity(0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      count.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSelected ? 11 : 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// Custom Painter to draw a clean, stylized geographic outline of Saudi Arabia
class SaudiOutlinePainter extends CustomPainter {
  final bool isDark;

  SaudiOutlinePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark 
          ? AppColors.primaryTealLight.withOpacity(0.06) 
          : AppColors.primaryTeal.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDark 
          ? AppColors.primaryTealLight.withOpacity(0.3) 
          : AppColors.primaryTeal.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Normalized Outline points of Saudi Arabia map (relative to size)
    // 0.0,0.0 is top-left, 1.0,1.0 is bottom-right
    final List<Offset> points = [
      Offset(0.12 * size.width, 0.28 * size.height), // Tabuk NW corner
      Offset(0.20 * size.width, 0.20 * size.height), // NW Jordan border
      Offset(0.32 * size.width, 0.16 * size.height), // North Al-Jawf
      Offset(0.46 * size.width, 0.12 * size.height), // Northern Borders N
      Offset(0.64 * size.width, 0.26 * size.height), // Kuwait corner
      Offset(0.72 * size.width, 0.32 * size.height), // Gulf coast N
      Offset(0.79 * size.width, 0.40 * size.height), // Gulf M
      Offset(0.85 * size.width, 0.48 * size.height), // Qatar/UAE border
      Offset(0.96 * size.width, 0.65 * size.height), // Oman border E
      Offset(0.92 * size.width, 0.83 * size.height), // Oman SE corner
      Offset(0.70 * size.width, 0.84 * size.height), // Empty Quarter S
      Offset(0.55 * size.width, 0.80 * size.height), // Najran border
      Offset(0.43 * size.width, 0.93 * size.height), // Jazan SW corner
      Offset(0.38 * size.width, 0.78 * size.height), // Asir Red Sea
      Offset(0.31 * size.width, 0.68 * size.height), // Jeddah Red Sea
      Offset(0.24 * size.width, 0.50 * size.height), // Yanbu / Madinah
      Offset(0.14 * size.width, 0.36 * size.height), // Tabuk Red Sea
    ];

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    // Draw background filling
    canvas.drawPath(path, paint);
    
    // Draw neon border stroke
    canvas.drawPath(path, borderPaint);

    // Optional: Draw stylized grid lines inside the country outline for premium sci-fi clinical feel
    final gridPaint = Paint()
      ..color = isDark 
          ? AppColors.primaryTealLight.withOpacity(0.04) 
          : AppColors.primaryTeal.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.clipPath(path);
    
    // Draw horizontal grid lines
    for (double y = 0.0; y < size.height; y += size.height / 15) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Draw vertical grid lines
    for (double x = 0.0; x < size.width; x += size.width / 15) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SaudiOutlinePainter oldDelegate) => oldDelegate.isDark != isDark;
}
