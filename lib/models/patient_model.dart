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

  // Saudi regional populations (2022 Census estimates)
  static const Map<String, int> saudiRegionPopulations = {
    'Riyadh': 8500000,
    'Makkah': 9000000,
    'Eastern Province': 5100000,
    'Madinah': 2400000,
    'Asir': 2300000,
    'Jazan': 1600000,
    'Al-Qassim': 1500000,
    'Tabuk': 1000000,
    'Ha\'il': 750000,
    'Najran': 600000,
    'Al-Jawf': 550000,
    'Al-Bahah': 500000,
    'Northern Borders': 400000,
  };

  Patient({
    required this.gender,
    required this.dateOfBirth,
    required this.region,
    required this.testHistory,
  });

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
