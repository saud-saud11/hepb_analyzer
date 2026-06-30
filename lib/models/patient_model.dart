enum HepBPhase {
  immuneTolerant,       // HBeAg-Positive Chronic Infection
  activeHBeAgPositive,  // HBeAg-Positive Chronic Hepatitis
  inactiveCarrier,      // HBeAg-Negative Chronic Infection
  activeHBeAgNegative,  // HBeAg-Negative Chronic Hepatitis
  resolved,             // Resolved HBV Infection
  susceptible,          // Susceptible / Negative
  vaccinated,           // Vaccinated
  indeterminate         // Indeterminate clinical phase
}

enum FibrosisRiskLevel {
  low,
  indeterminate,
  high,
  unknown
}

extension HepBPhaseExtension on HepBPhase {
  String get nameEn {
    switch (this) {
      case HepBPhase.immuneTolerant:
        return 'HBeAg-Positive Chronic Infection (Immune Tolerant)';
      case HepBPhase.activeHBeAgPositive:
        return 'HBeAg-Positive Chronic Hepatitis';
      case HepBPhase.inactiveCarrier:
        return 'HBeAg-Negative Chronic Infection (Inactive Carrier)';
      case HepBPhase.activeHBeAgNegative:
        return 'HBeAg-Negative Chronic Hepatitis';
      case HepBPhase.resolved:
        return 'Resolved HBV Infection';
      case HepBPhase.susceptible:
        return 'Susceptible (Uninfected)';
      case HepBPhase.vaccinated:
        return 'Vaccinated / Immune';
      case HepBPhase.indeterminate:
        return 'Indeterminate Profile';
    }
  }

  String get nameAr {
    switch (this) {
      case HepBPhase.immuneTolerant:
        return 'عدوى مزمنة موجبة الـ HBeAg (متحمل مناعياً)';
      case HepBPhase.activeHBeAgPositive:
        return 'التهاب كبدي مزمن نشط موجب الـ HBeAg';
      case HepBPhase.inactiveCarrier:
        return 'عدوى مزمنة سالبة الـ HBeAg (حامل خامل)';
      case HepBPhase.activeHBeAgNegative:
        return 'التهاب كبدي مزمن نشط سالب الـ HBeAg';
      case HepBPhase.resolved:
        return 'عدوى كبدية وبائية ب متشافية';
      case HepBPhase.susceptible:
        return 'عرضة للإصابة (غير مصاب)';
      case HepBPhase.vaccinated:
        return 'مُحصّن / مُطعّم';
      case HepBPhase.indeterminate:
        return 'مظهر سريري غير محدد';
    }
  }
}

extension FibrosisRiskLevelExtension on FibrosisRiskLevel {
  String get nameEn {
    switch (this) {
      case FibrosisRiskLevel.low:
        return 'Low Risk (F0-F1)';
      case FibrosisRiskLevel.indeterminate:
        return 'Intermediate Risk';
      case FibrosisRiskLevel.high:
        return 'High Risk (F3-F4)';
      case FibrosisRiskLevel.unknown:
        return 'Insufficient Data';
    }
  }

  String get nameAr {
    switch (this) {
      case FibrosisRiskLevel.low:
        return 'خطر منخفض (F0-F1)';
      case FibrosisRiskLevel.indeterminate:
        return 'خطر متوسط';
      case FibrosisRiskLevel.high:
        return 'خطر مرتفع (تليف متقدم F3-F4)';
      case FibrosisRiskLevel.unknown:
        return 'بيانات غير كافية';
    }
  }
}

class TestResult {
  final String testName;
  final int year;
  final dynamic value;

  TestResult({
    required this.testName,
    required this.year,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'testName': testName,
        'year': year,
        'value': value,
      };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
        testName: json['testName'],
        year: json['year'],
        value: json['value'],
      );
}

class Patient {
  final String gender;
  final String dateOfBirth;
  final String region;
  // Map of testName -> Map of year -> value
  final Map<String, Map<int, dynamic>> testHistory;

  Patient({
    required this.gender,
    required this.dateOfBirth,
    required this.region,
    required this.testHistory,
  });

  String get uniqueKey => '${gender}_${dateOfBirth}_$region'.toLowerCase();

  int getAgeInYear(int testYear) {
    try {
      // DOB can be a full date (e.g. 1985-05-12) or just a year (e.g. 1985)
      int birthYear;
      if (dateOfBirth.length >= 4) {
        final parsedYear = int.tryParse(dateOfBirth.substring(0, 4));
        if (parsedYear != null) {
          birthYear = parsedYear;
        } else {
          birthYear = DateTime.now().year - 40; // Default fallback
        }
      } else {
        birthYear = int.tryParse(dateOfBirth) ?? (DateTime.now().year - 40);
      }
      return testYear - birthYear;
    } catch (_) {
      return 40; // Default fallback
    }
  }

  dynamic getLatestValue(String testName, [int? targetYear]) {
    final history = testHistory[testName.toUpperCase().trim()];
    if (history == null || history.isEmpty) return null;

    if (targetYear != null) {
      return history[targetYear];
    }

    // Find the latest year's value
    final sortedYears = history.keys.toList()..sort();
    return history[sortedYears.last];
  }

  int? getLatestYearForTest(String testName) {
    final history = testHistory[testName.toUpperCase().trim()];
    if (history == null || history.isEmpty) return null;
    final sortedYears = history.keys.toList()..sort();
    return sortedYears.last;
  }

  int getLatestYear() {
    int latest = 2025;
    for (var history in testHistory.values) {
      if (history.isNotEmpty) {
        final sorted = history.keys.toList()..sort();
        if (sorted.last > latest) {
          latest = sorted.last;
        }
      }
    }
    return latest;
  }

  // Parse result value as numeric (e.g. ALT, AST, Platelets, HBV DNA)
  double? getNumericValue(String testName, [int? targetYear]) {
    final val = getLatestValue(testName, targetYear);
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      // Handle scientific notation or numbers with commas/spaces
      final clean = val.replaceAll(RegExp(r'[^\d\.\-eE]'), '');
      return double.tryParse(clean);
    }
    return null;
  }

  // Parse qualitative value as boolean / flag (e.g. HBsAg, HBeAg)
  bool? getBooleanValue(String testName, [int? targetYear]) {
    final val = getLatestValue(testName, targetYear);
    if (val == null) return null;
    if (val is bool) return val;
    final strVal = val.toString().toLowerCase().trim();
    if (strVal == 'positive' ||
        strVal == 'reactive' ||
        strVal == '+' ||
        strVal == 'yes' ||
        strVal == '1' ||
        strVal == 'pos' ||
        strVal == 'موجب') {
      return true;
    }
    if (strVal == 'negative' ||
        strVal == 'non-reactive' ||
        strVal == '-' ||
        strVal == 'no' ||
        strVal == '0' ||
        strVal == 'neg' ||
        strVal == 'سالب') {
      return false;
    }
    return null;
  }

  // Calculated properties based on latest available data or a specific year
  double? getAlt([int? year]) => getNumericValue('ALT', year);
  double? getAst([int? year]) => getNumericValue('AST', year);
  double? getPlatelets([int? year]) => getNumericValue('PLATELETS', year) ?? getNumericValue('PLT', year);
  double? getHbvDna([int? year]) => getNumericValue('HBV DNA', year) ?? getNumericValue('HBV_DNA', year) ?? getNumericValue('VIRAL LOAD', year) ?? getNumericValue('PCR', year);
  bool? getHbsag([int? year]) => getBooleanValue('HBsAg', year) ?? getBooleanValue('HBSAG_TEST', year);
  bool? getHbeag([int? year]) => getBooleanValue('HBeAg', year) ?? getBooleanValue('HBEAG_TEST', year);
  bool? getAntiHbs([int? year]) => getBooleanValue('Anti-HBs', year) ?? getBooleanValue('ANTI-HBS', year) ?? getBooleanValue('HBSAB', year);
  bool? getAntiHbc([int? year]) => getBooleanValue('Anti-HBc', year) ?? getBooleanValue('ANTI-HBC', year) ?? getBooleanValue('HBCAB', year);

  // FIB-4 score calculation
  // Formula: (Age * AST) / (Platelets * sqrt(ALT))
  double? getFib4([int? year]) {
    final altVal = getAlt(year);
    final astVal = getAst(year);
    final pltVal = getPlatelets(year);
    if (altVal == null || astVal == null || pltVal == null || altVal <= 0 || pltVal <= 0) {
      return null;
    }

    final int testYear = year ?? getLatestYear();
    final int ageVal = getAgeInYear(testYear);
    
    // Platelets should be in 10^9/L. If platelets are entered as e.g. 200,000 instead of 200:
    double adjustedPlt = pltVal;
    if (pltVal > 1000) {
      adjustedPlt = pltVal / 1000.0;
    }
    
    import_math:
    final double altSqrt = double.parse(altVal.toString()); // sqrt placeholder
    // Let's implement standard sqrt
    final double result = (ageVal * astVal) / (adjustedPlt * _squareRoot(altVal));
    return double.parse(result.toStringAsFixed(2));
  }

  // APRI score calculation
  // Formula: ((AST / AST_ULN) * 100) / Platelets
  // standard AST ULN (Upper Limit of Normal) is around 40 U/L
  double? getApri([int? year]) {
    final astVal = getAst(year);
    final pltVal = getPlatelets(year);
    if (astVal == null || pltVal == null || pltVal <= 0) {
      return null;
    }

    double adjustedPlt = pltVal;
    if (pltVal > 1000) {
      adjustedPlt = pltVal / 1000.0;
    }

    final double result = ((astVal / 40.0) * 100) / adjustedPlt;
    return double.parse(result.toStringAsFixed(2));
  }

  // Helper square root function to avoid importing dart:math in pure model files
  double _squareRoot(double number) {
    if (number < 0) return 0;
    double t;
    double squareRoot = number / 2;
    do {
      t = squareRoot;
      squareRoot = (t + (number / t)) / 2;
    } while ((t - squareRoot).abs() > 0.00001);
    return squareRoot;
  }

  // Staging disease phase according to EASL guidelines
  HepBPhase getDiseasePhase([int? year]) {
    final hbsagVal = getHbsag(year);
    final hbeagVal = getHbeag(year);
    final altVal = getAlt(year);
    final dnaVal = getHbvDna(year);
    final antiHbsVal = getAntiHbs(year);
    final antiHbcVal = getAntiHbc(year);

    // 1. If HBsAg is negative
    if (hbsagVal == false) {
      if (antiHbsVal == true && antiHbcVal == false) {
        return HepBPhase.vaccinated;
      }
      if (antiHbcVal == true) {
        return HepBPhase.resolved;
      }
      if (antiHbsVal == false && antiHbcVal == false) {
        return HepBPhase.susceptible;
      }
      return HepBPhase.resolved; // default for negative HBsAg with exposure
    }

    // 2. If HBsAg is positive (or missing, assume positive if this is a hep b registry sheet)
    if (hbsagVal != false) {
      if (hbeagVal == true) {
        // HBeAg positive phases
        if (altVal != null && dnaVal != null) {
          if (altVal <= 40 && dnaVal >= 10000000) {
            return HepBPhase.immuneTolerant; // Phase 1: HBeAg-Positive Chronic Infection
          }
          if (altVal > 40 && dnaVal >= 20000) {
            return HepBPhase.activeHBeAgPositive; // Phase 2: HBeAg-Positive Chronic Hepatitis
          }
        }
        return HepBPhase.activeHBeAgPositive; // fallback for positive HBeAg
      } else if (hbeagVal == false) {
        // HBeAg negative phases
        if (altVal != null && dnaVal != null) {
          if (altVal <= 40 && dnaVal < 2000) {
            return HepBPhase.inactiveCarrier; // Phase 3: HBeAg-Negative Chronic Infection (Inactive Carrier)
          }
          if (altVal > 40 && dnaVal >= 2000) {
            return HepBPhase.activeHBeAgNegative; // Phase 4: HBeAg-Negative Chronic Hepatitis
          }
        }
        // Fallback: if ALT normal and DNA low, assume inactive carrier
        if (altVal != null && altVal <= 40) return HepBPhase.inactiveCarrier;
        return HepBPhase.activeHBeAgNegative;
      }
    }

    return HepBPhase.indeterminate;
  }

  FibrosisRiskLevel getFibrosisRisk([int? year]) {
    final fib4Val = getFib4(year);
    if (fib4Val == null) return FibrosisRiskLevel.unknown;

    if (fib4Val < 1.45) {
      return FibrosisRiskLevel.low;
    } else if (fib4Val > 3.25) {
      return FibrosisRiskLevel.high;
    } else {
      return FibrosisRiskLevel.indeterminate;
    }
  }

  // Convert to JSON map for Hive storage
  Map<String, dynamic> toJson() {
    final Map<String, Map<String, dynamic>> rawHistory = {};
    testHistory.forEach((test, yearMap) {
      rawHistory[test] = yearMap.map((yr, val) => MapEntry(yr.toString(), val));
    });

    return {
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'region': region,
      'testHistory': rawHistory,
    };
  }

  // Parse from JSON map for Hive storage
  factory Patient.fromJson(Map<String, dynamic> json) {
    final Map<String, Map<int, dynamic>> parsedHistory = {};
    final rawHistory = json['testHistory'] as Map<dynamic, dynamic>? ?? {};

    rawHistory.forEach((test, yearMap) {
      final Map<int, dynamic> yrMap = {};
      if (yearMap is Map) {
        yearMap.forEach((yrStr, val) {
          final yr = int.tryParse(yrStr.toString()) ?? 2025;
          yrMap[yr] = val;
        });
      }
      parsedHistory[test.toString().toUpperCase().trim()] = yrMap;
    });

    return Patient(
      gender: json['gender'] ?? 'Unknown',
      dateOfBirth: json['dateOfBirth'] ?? '1985',
      region: json['region'] ?? 'Unknown',
      testHistory: parsedHistory,
    );
  }
}
