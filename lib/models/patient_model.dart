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

  // Saudi regional populations (General Authority for Statistics Census 2022)
  static const Map<String, int> saudiRegionPopulations = {
    'Riyadh': 8591748,
    'Makkah': 7769994,
    'Eastern Province': 5125254,
    'Madinah': 2389452,
    'Asir': 2024285,
    'Jazan': 1404997,
    'Al-Qassim': 1336179,
    'Tabuk': 886036,
    'Ha\'il': 746406,
    'Najran': 592300,
    'Al-Jawf': 595822,
    'Al-Bahah': 339174,
    'Northern Borders': 373577,
  };

  Patient({
    required this.gender,
    required this.dateOfBirth,
    required this.region,
    required this.testHistory,
  });

  int get totalTestsCount {
    int count = 0;
    for (var history in testHistory.values) {
      count += history.length;
    }
    return count;
  }

  String get uniqueKey => '${gender}_${dateOfBirth}_$region'.toLowerCase();

  int getAgeInYear(int testYear) {
    try {
      int birthYear;
      if (dateOfBirth.length >= 4) {
        final parsedYear = int.tryParse(dateOfBirth.substring(0, 4));
        if (parsedYear != null) {
          birthYear = parsedYear;
        } else {
          birthYear = DateTime.now().year - 40;
        }
      } else {
        birthYear = int.tryParse(dateOfBirth) ?? (DateTime.now().year - 40);
      }
      return testYear - birthYear;
    } catch (_) {
      return 40;
    }
  }

  dynamic getLatestValue(String testName, [int? targetYear]) {
    final history = testHistory[testName.toUpperCase().trim()];
    if (history == null || history.isEmpty) return null;

    if (targetYear != null) {
      return history[targetYear];
    }

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

  double? getNumericValue(String testName, [int? targetYear]) {
    final val = getLatestValue(testName, targetYear);
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^\d\.\-eE]'), '');
      return double.tryParse(clean);
    }
    return null;
  }

  static Map<String, dynamic> parseValueAndUnit(dynamic rawVal) {
    if (rawVal == null) return {'value': null, 'unit': null};
    if (rawVal is num) {
      return {'value': rawVal.toDouble(), 'unit': null};
    }
    final str = rawVal.toString().trim();
    
    // Regex to match number and subsequent text (unit)
    // Matches e.g. "423 m[IU]/L" -> Group 1: "423", Group 2: "m[IU]/L"
    final regExp = RegExp(r'^([0-9\.\-]+)\s*(.*)$');
    final match = regExp.firstMatch(str);
    if (match != null) {
      final numStr = match.group(1);
      final unitStr = match.group(2)?.trim();
      final dVal = double.tryParse(numStr ?? '');
      return {
        'value': dVal,
        'unit': unitStr?.isNotEmpty == true ? unitStr : null,
      };
    }
    return {'value': null, 'unit': null};
  }

  bool? getBooleanValue(String testName, [int? targetYear]) {
    final val = getLatestValue(testName, targetYear);
    if (val == null) return null;
    if (val is bool) return val;

    final cleanTest = testName.toUpperCase().trim();
    // Check if the test represents Anti-HBs / HBsAb (e.g. surface antibody test)
    if (cleanTest.contains('HEPATITIS B VIRUS SURFACE AB') ||
        cleanTest.contains('HBSAB') ||
        cleanTest.contains('ANTI-HBS') ||
        cleanTest.contains('ANTI - HBS') ||
        cleanTest.contains('SURFACE AB')) {
      final parsed = parseValueAndUnit(val);
      final double? dVal = parsed['value'];
      final String? unit = parsed['unit'];

      if (dVal != null) {
        // Normalize unit text: lowercase and strip spaces
        final normUnit = (unit ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');
        
        // 10 mIU/mL equals 10000 mIU/L (since 1 mL = 0.001 L)
        if (normUnit == 'm[iu]/l' || normUnit == 'miu/l') {
          return dVal >= 10000;
        } else if (normUnit == 'miu/ml' || normUnit == 'iu/l') {
          return dVal >= 10;
        } else {
          // Default fallback (assume mIU/mL if not specified)
          return dVal >= 10;
        }
      }
    }

    final strVal = val.toString().toLowerCase().trim();
    if (strVal == 'positive' ||
        strVal == 'reactive' ||
        strVal == '+' ||
        strVal == 'yes' ||
        strVal == '1' ||
        strVal == 'pos' ||
        strVal == 'موجب' ||
        strVal.contains('immune')) {
      return true;
    }
    if (strVal == 'negative' ||
        strVal == 'non-reactive' ||
        strVal == '-' ||
        strVal == 'no' ||
        strVal == '0' ||
        strVal == 'neg' ||
        strVal == 'سالب' ||
        strVal.contains('not immune')) {
      return false;
    }
    return null;
  }

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
