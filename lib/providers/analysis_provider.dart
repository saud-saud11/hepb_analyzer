import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/patient_model.dart';

class AnalysisProvider extends ChangeNotifier {
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = false;
  double _parseProgress = 0.0;
  String? _fileName;
  int? _fileSize;
  String? _errorMessage;

  // Cache Box
  static const String boxName = 'patients_cache_box';
  late Box _cacheBox;

  // Filters
  String _selectedGender = 'All';
  String _selectedRegion = 'All';
  String _selectedYear = 'All';
  String _searchQuery = '';

  // Options lists populated from data
  List<String> _availableRegions = [];
  List<String> _availableYears = [];
  List<String> _uniqueTestNames = [];

  // Getters
  List<Patient> get patients => _filteredPatients;
  List<Patient> get allPatients => _allPatients;
  bool get isLoading => _isLoading;
  double get parseProgress => _parseProgress;
  String? get fileName => _fileName;
  int? get fileSize => _fileSize;
  String? get errorMessage => _errorMessage;

  String get selectedGender => _selectedGender;
  String get selectedRegion => _selectedRegion;
  String get selectedYear => _selectedYear;
  String get searchQuery => _searchQuery;

  List<String> get availableRegions => _availableRegions;
  List<String> get availableYears => _availableYears;
  List<String> get uniqueTestNames => _uniqueTestNames;

  AnalysisProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
    _isLoading = true;
    notifyListeners();
    try {
      _cacheBox = await Hive.openBox(boxName);
      _loadCachedData();
    } catch (e) {
      _errorMessage = 'Failed to initialize local database: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadCachedData() {
    try {
      final cachedList = _cacheBox.get('patients_list');
      if (cachedList != null && cachedList is List) {
        _allPatients = cachedList
            .map((item) => Patient.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _fileName = _cacheBox.get('file_name');
        _fileSize = _cacheBox.get('file_size');
        _updateFiltersList();
        _applyFilters();
      }
    } catch (e) {
      _errorMessage = 'Failed to load cached patients: $e';
    }
  }

  Future<void> clearCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cacheBox.clear();
      _allPatients = [];
      _filteredPatients = [];
      _fileName = null;
      _fileSize = null;
      _availableRegions = [];
      _availableYears = [];
      _uniqueTestNames = [];
      _selectedGender = 'All';
      _selectedRegion = 'All';
      _selectedYear = 'All';
      _searchQuery = '';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to clear cache: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateFiltersList() {
    // Collect unique regions
    final regions = _allPatients.map((p) => p.region).toSet().toList()..sort();
    _availableRegions = ['All', ...regions];

    // Collect unique years & unique tests
    final yearsSet = <int>{};
    final testsSet = <String>{};
    for (var p in _allPatients) {
      for (var entry in p.testHistory.entries) {
        testsSet.add(entry.key);
        yearsSet.addAll(entry.value.keys);
      }
    }
    final years = yearsSet.map((y) => y.toString()).toList()..sort();
    _availableYears = ['All', ...years];

    _uniqueTestNames = testsSet.toList()..sort();
  }

  // Helper: Extract primitive types (String, num, bool) from excel package's CellValue subclasses
  dynamic _cleanCellValue(dynamic val) {
    if (val == null) return null;
    if (val is num || val is String || val is bool) return val;
    // Recursive extraction for CellValue wraps
    try {
      final dynamic inner = (val as dynamic).value;
      if (inner != null) return _cleanCellValue(inner);
    } catch (_) {}
    return val.toString();
  }

  // Unified File Parsing Entrypoint
  Future<void> parseFile(Uint8List bytes, String name, int size) async {
    _isLoading = true;
    _parseProgress = 0.0;
    _errorMessage = null;
    _fileName = name;
    _fileSize = size;
    notifyListeners();

    try {
      final cleanName = name.toLowerCase();
      if (cleanName.endsWith('.csv')) {
        await _parseCsvFile(bytes);
      } else if (cleanName.endsWith('.xlsx') || cleanName.endsWith('.xls')) {
        await _parseExcelFile(bytes);
      } else {
        throw Exception('Unsupported file format. Please upload .csv or .xlsx files.');
      }

      // Cache the parsed list in Hive
      final List<Map<String, dynamic>> jsonList = _allPatients.map((p) => p.toJson()).toList();
      await _cacheBox.put('patients_list', jsonList);
      await _cacheBox.put('file_name', name);
      await _cacheBox.put('file_size', size);

      _applyFilters();
    } catch (e) {
      _errorMessage = 'Parsing failed: $e';
    } finally {
      _isLoading = false;
      _parseProgress = 1.0;
      notifyListeners();
    }
  }

  // Helper: Find the header row index (scanning first 10 rows)
  int _findHeaderRowIndex(List<List<dynamic>> rows) {
    for (int i = 0; i < rows.length && i < 10; i++) {
      final row = rows[i];
      for (var cell in row) {
        final cellStr = cell?.toString().toLowerCase() ?? '';
        if (cellStr.contains('gender') || cellStr.contains('sex') || cellStr.contains('جنس') ||
            cellStr.contains('test_name') || cellStr.contains('test') || cellStr.contains('region_en')) {
          return i; // Found header row
        }
      }
    }
    return 0; // Fallback to first row
  }

  // Helper: Find indexes mapping keywords to Excel/CSV columns
  Map<String, int> _findColumnIndexes(List<dynamic> headerRow) {
    int genderIdx = 0;
    int dobIdx = 1;
    int regionIdx = 2;
    int testNameIdx = 3;
    int yearIdx = 4;
    int valueIdx = 5;

    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      final String colName = cell?.toString().toLowerCase().trim() ?? '';

      if (colName.contains('gender') || colName.contains('sex') || colName == 'جنس') {
        genderIdx = i;
      } else if (colName.contains('dateofbirth') || colName.contains('dob') || colName.contains('birth') || colName.contains('ميلاد')) {
        dobIdx = i;
      } else if (colName.contains('region') || colName.contains('area') || colName.contains('منطقة')) {
        regionIdx = i;
      } else if (colName.contains('test_name') || colName.contains('test') || colName.contains('marker') || colName.contains('فحص')) {
        testNameIdx = i;
      } else if (colName.contains('result_year') || colName.contains('year') || colName.contains('سنة') || colName.contains('تاريخ الفحص')) {
        yearIdx = i;
      } else if (colName.contains('result_value') || colName.contains('value') || colName.contains('result') || colName.contains('نتيجة') || colName.contains('النتيجة')) {
        valueIdx = i;
      }
    }

    return {
      'gender': genderIdx,
      'dob': dobIdx,
      'region': regionIdx,
      'testName': testNameIdx,
      'year': yearIdx,
      'value': valueIdx,
    };
  }

  // Fast CSV Parser with Dynamic Columns & Scrambled Header Support
  Future<void> _parseCsvFile(Uint8List bytes) async {
    final String csvText = utf8.decode(bytes);
    final List<String> lines = csvText.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return;

    // Build lists of rows
    final List<List<String>> rows = [];
    for (var line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;
      rows.add(cleanLine.split(',').map((cell) => cell.replaceAll('"', '').trim()).toList());
    }

    if (rows.isEmpty) return;

    // Detect header row dynamically
    final headerRowIdx = _findHeaderRowIndex(rows);
    final headerRow = rows[headerRowIdx];
    final colMap = _findColumnIndexes(headerRow);

    final startIdx = headerRowIdx + 1;
    final int totalLinesToProcess = rows.length - startIdx;
    final Map<String, Patient> tempPatientMap = {};
    int processedLinesCount = 0;

    for (int i = startIdx; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= colMap['value']! || row.length <= colMap['testName']!) continue;

      final gender = row[colMap['gender']!];
      final dob = row[colMap['dob']!];
      final region = row[colMap['region']!];
      final testName = row[colMap['testName']!].toUpperCase();
      final resultYearStr = row[colMap['year']!];
      final resultValueStr = row[colMap['value']!];

      if (testName.isEmpty || resultValueStr.isEmpty) continue;

      final resultYear = int.tryParse(resultYearStr) ?? 2025;
      
      dynamic resultValue;
      final numericCheck = double.tryParse(resultValueStr);
      if (numericCheck != null) {
        resultValue = numericCheck;
      } else {
        resultValue = resultValueStr;
      }

      final key = '${gender}_${dob}_$region'.toLowerCase();

      Patient patient;
      if (tempPatientMap.containsKey(key)) {
        patient = tempPatientMap[key]!;
      } else {
        patient = Patient(
          gender: gender,
          dateOfBirth: dob,
          region: region,
          testHistory: {},
        );
        tempPatientMap[key] = patient;
      }

      if (!patient.testHistory.containsKey(testName)) {
        patient.testHistory[testName] = {};
      }
      patient.testHistory[testName]![resultYear] = resultValue;

      processedLinesCount++;

      if (processedLinesCount % 5000 == 0) {
        _parseProgress = processedLinesCount / totalLinesToProcess;
        notifyListeners();
        await Future.delayed(Duration.zero);
      }
    }

    _allPatients = tempPatientMap.values.toList();
    _updateFiltersList();
  }

  // Optimized Excel Parser with Dynamic Columns & Scrambled Header Support
  Future<void> _parseExcelFile(Uint8List bytes) async {
    final Excel excel = Excel.decodeBytes(bytes);
    final String sheetName = excel.tables.keys.first;
    final Sheet sheet = excel.tables[sheetName]!;
    
    final int maxRows = sheet.maxRows;
    if (maxRows <= 1) {
      throw Exception('The uploaded sheet is empty or contains only headers.');
    }

    // Convert sheet rows list to a list of lists of Cell values for scanner
    final List<List<dynamic>> rowsList = [];
    for (var row in sheet.rows) {
      rowsList.add(row.map((cell) => cell?.value).toList());
    }

    // Find header dynamically
    final headerRowIdx = _findHeaderRowIndex(rowsList);
    final headerRow = sheet.rows[headerRowIdx];
    final colMap = _findColumnIndexes(headerRow.map((c) => c?.value).toList());

    final startRow = headerRowIdx + 1;
    final int totalRowsToProcess = maxRows - startRow;
    final Map<String, Patient> tempPatientMap = {};

    int processedRowsCount = 0;

    for (int i = startRow; i < maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      // Extract and clean values safely checking row bounds
      final genderVal = colMap['gender']! < row.length ? row[colMap['gender']!]?.value : null;
      final dobVal = colMap['dob']! < row.length ? row[colMap['dob']!]?.value : null;
      final regionVal = colMap['region']! < row.length ? row[colMap['region']!]?.value : null;
      final testNameVal = colMap['testName']! < row.length ? row[colMap['testName']!]?.value : null;
      final yearVal = colMap['year']! < row.length ? row[colMap['year']!]?.value : null;
      final valueVal = colMap['value']! < row.length ? row[colMap['value']!]?.value : null;

      final gender = _cleanCellValue(genderVal)?.toString().trim() ?? 'Unknown';
      final dob = _cleanCellValue(dobVal)?.toString().trim() ?? 'Unknown';
      final region = _cleanCellValue(regionVal)?.toString().trim() ?? 'Unknown';
      final testName = _cleanCellValue(testNameVal)?.toString().trim().toUpperCase() ?? '';
      final resultYearStr = _cleanCellValue(yearVal)?.toString().trim() ?? '2025';
      final resultValue = _cleanCellValue(valueVal);

      if (testName.isEmpty || resultValue == null) continue;

      final resultYear = int.tryParse(resultYearStr) ?? 2025;
      final key = '${gender}_${dob}_$region'.toLowerCase();

      Patient patient;
      if (tempPatientMap.containsKey(key)) {
        patient = tempPatientMap[key]!;
      } else {
        patient = Patient(
          gender: gender,
          dateOfBirth: dob,
          region: region,
          testHistory: {},
        );
        tempPatientMap[key] = patient;
      }

      if (!patient.testHistory.containsKey(testName)) {
        patient.testHistory[testName] = {};
      }
      patient.testHistory[testName]![resultYear] = resultValue;

      processedRowsCount++;

      if (processedRowsCount % 2000 == 0) {
        _parseProgress = processedRowsCount / totalRowsToProcess;
        notifyListeners();
        await Future.delayed(Duration.zero);
      }
    }

    _allPatients = tempPatientMap.values.toList();
    _updateFiltersList();
  }

  // Start Manual Registry from scratch
  Future<void> startManualEntry() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allPatients = [];
      _filteredPatients = [];
      _fileName = 'Manual Registry';
      _fileSize = 0;
      _updateFiltersList();
      
      await _cacheBox.put('patients_list', <Map<String, dynamic>>[]);
      await _cacheBox.put('file_name', 'Manual Registry');
      await _cacheBox.put('file_size', 0);
      
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to start manual registry: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Insert or Append a patient record manually
  Future<void> addManualRecord({
    required String gender,
    required String dob,
    required String region,
    required String testName,
    required int year,
    required dynamic value,
  }) async {
    final cleanGender = gender.trim();
    final cleanDob = dob.trim();
    final cleanRegion = region.trim();
    final cleanTest = testName.trim().toUpperCase();
    
    // Auto-detect double value if parseable
    dynamic finalVal = value;
    if (value is String) {
      final doubleCheck = double.tryParse(value);
      if (doubleCheck != null) {
        finalVal = doubleCheck;
      }
    }

    final key = '${cleanGender}_${cleanDob}_$cleanRegion'.toLowerCase();
    
    Patient? existing;
    for (var p in _allPatients) {
      if (p.uniqueKey == key) {
        existing = p;
        break;
      }
    }

    if (existing != null) {
      if (!existing.testHistory.containsKey(cleanTest)) {
        existing.testHistory[cleanTest] = {};
      }
      existing.testHistory[cleanTest]![year] = finalVal;
    } else {
      final newPatient = Patient(
        gender: cleanGender,
        dateOfBirth: cleanDob,
        region: cleanRegion,
        testHistory: {
          cleanTest: {year: finalVal}
        },
      );
      _allPatients.add(newPatient);
    }

    _updateFiltersList();
    
    // Save to Hive cache
    final List<Map<String, dynamic>> jsonList = _allPatients.map((p) => p.toJson()).toList();
    await _cacheBox.put('patients_list', jsonList);
    if (_fileName == null) {
      _fileName = 'Manual Registry';
      _fileSize = 0;
      await _cacheBox.put('file_name', 'Manual Registry');
      await _cacheBox.put('file_size', 0);
    }
    
    _applyFilters();
  }

  // Setters for filters
  void setGenderFilter(String val) {
    _selectedGender = val;
    _applyFilters();
  }

  void setRegionFilter(String val) {
    _selectedRegion = val;
    _applyFilters();
  }

  void setYearFilter(String val) {
    _selectedYear = val;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Apply filters
  void _applyFilters() {
    _filteredPatients = _allPatients.where((patient) {
      if (_selectedGender != 'All' &&
          patient.gender.toLowerCase() != _selectedGender.toLowerCase()) {
        return false;
      }

      if (_selectedRegion != 'All' &&
          patient.region.toLowerCase() != _selectedRegion.toLowerCase()) {
        return false;
      }

      int? targetYear;
      if (_selectedYear != 'All') {
        targetYear = int.tryParse(_selectedYear);
        if (targetYear == null) return false;

        bool hasTestInYear = false;
        for (var history in patient.testHistory.values) {
          if (history.containsKey(targetYear)) {
            hasTestInYear = true;
            break;
          }
        }
        if (!hasTestInYear) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesRegion = patient.region.toLowerCase().contains(q);
        final matchesGender = patient.gender.toLowerCase().contains(q);
        final matchesDob = patient.dateOfBirth.toLowerCase().contains(q);
        return matchesRegion || matchesGender || matchesDob;
      }

      return true;
    }).toList();

    notifyListeners();
  }

  // Age group distribution calculation
  List<Map<String, dynamic>> get ageGroupDistribution {
    final Map<String, List<Patient>> groups = {
      'Under 15': [],
      '15 - 29': [],
      '30 - 44': [],
      '45 - 59': [],
      '60+': [],
    };

    for (var p in _filteredPatients) {
      final age = p.getAgeInYear(p.getLatestYear());
      if (age < 15) {
        groups['Under 15']!.add(p);
      } else if (age < 30) {
        groups['15 - 29']!.add(p);
      } else if (age < 45) {
        groups['30 - 44']!.add(p);
      } else if (age < 60) {
        groups['45 - 59']!.add(p);
      } else {
        groups['60+']!.add(p);
      }
    }

    final int total = _filteredPatients.length;
    final List<Map<String, dynamic>> list = [];

    final translations = {
      'Under 15': 'Under 15 / أقل من 15',
      '15 - 29': '15 - 29',
      '30 - 44': '30 - 44',
      '45 - 59': '45 - 59',
      '60+': '60 and older / 60 فما فوق',
    };

    groups.forEach((label, patientsList) {
      final count = patientsList.length;
      final percent = total > 0 ? (count / total) * 100 : 0.0;
      final males = patientsList.where((p) => p.gender.toLowerCase() == 'male' || p.gender.toLowerCase() == 'm').length;
      final females = count - males;

      list.add({
        'group': label,
        'labelAr': translations[label],
        'count': count,
        'percentage': double.parse(percent.toStringAsFixed(1)),
        'males': males,
        'females': females,
      });
    });

    return list;
  }

  // Stats Card Info
  int get totalPatientsCount => _filteredPatients.length;
  int get totalUniqueTestsCount => _uniqueTestNames.length;
  int get totalRegionsCount => _availableRegions.length - 1; // Subtract 'All'

  int get malesCount => _filteredPatients.where((p) => p.gender.toLowerCase() == 'male' || p.gender.toLowerCase() == 'm').length;
  int get femalesCount => _filteredPatients.where((p) => p.gender.toLowerCase() == 'female' || p.gender.toLowerCase() == 'f').length;

  // Region Patient Counts (used for Saudi map outline)
  Map<String, int> get regionCounts {
    final Map<String, int> counts = {};
    for (var p in _filteredPatients) {
      final cleanRegion = p.region.trim();
      counts[cleanRegion] = (counts[cleanRegion] ?? 0) + 1;
    }
    return counts;
  }

  // Region analysis details (table representation)
  List<Map<String, dynamic>> get regionAnalysisTable {
    final Map<String, int> counts = regionCounts;
    final int total = totalPatientsCount;

    final List<Map<String, dynamic>> table = [];

    Patient.saudiRegionPopulations.forEach((regionName, population) {
      // Find matches in counts (accounting for variations)
      int count = 0;
      counts.forEach((key, val) {
        if (_isRegionMatch(key, regionName)) {
          count += val;
        }
      });

      final double prevalence = population > 0 ? (count / population) * 100 : 0.0;
      final double cohortShare = total > 0 ? (count / total) * 100 : 0.0;

      table.add({
        'region': regionName,
        'population': population,
        'patients': count,
        'prevalence': double.parse(prevalence.toStringAsFixed(5)), // Prevalence is usually small
        'cohortShare': double.parse(cohortShare.toStringAsFixed(2)),
      });
    });

    // Sort table by patient count descending
    table.sort((a, b) => (b['patients'] as int).compareTo(a['patients'] as int));
    return table;
  }

  bool _isRegionMatch(String input, String target) {
    final cleanInput = input.toLowerCase().trim();
    final cleanTarget = target.toLowerCase().trim();

    if (cleanInput == cleanTarget) return true;
    if (cleanTarget.contains('eastern') && (cleanInput.contains('eastern') || cleanInput.contains('الشرقية') || cleanInput.contains('dammam'))) return true;
    if (cleanTarget.contains('riyadh') && (cleanInput.contains('riyadh') || cleanInput.contains('الرياض') || cleanInput.contains('riyad'))) return true;
    if (cleanTarget.contains('makkah') && (cleanInput.contains('makkah') || cleanInput.contains('mecca') || cleanInput.contains('مكة'))) return true;
    if (cleanTarget.contains('madinah') && (cleanInput.contains('madinah') || cleanInput.contains('madina') || cleanInput.contains('المدينة'))) return true;
    if (cleanTarget.contains('qassim') && (cleanInput.contains('qassim') || cleanInput.contains('القصيم') || cleanInput.contains('gassim'))) return true;
    if (cleanTarget.contains('hail') && (cleanInput.contains('hail') || cleanInput.contains('حائل'))) return true;
    if (cleanTarget.contains('tabuk') && (cleanInput.contains('tabuk') || cleanInput.contains('تبوك'))) return true;
    if (cleanTarget.contains('jawf') && (cleanInput.contains('jawf') || cleanInput.contains('الجوف'))) return true;
    if (cleanTarget.contains('borders') && (cleanInput.contains('border') || cleanInput.contains('شمالية') || cleanInput.contains('arar'))) return true;
    if (cleanTarget.contains('jazan') && (cleanInput.contains('jazan') || cleanInput.contains('jizan') || cleanInput.contains('جازان'))) return true;
    if (cleanTarget.contains('asir') && (cleanInput.contains('asir') || cleanInput.contains('عسير') || cleanInput.contains('abha'))) return true;
    if (cleanTarget.contains('najran') && (cleanInput.contains('najran') || cleanInput.contains('نجران'))) return true;
    if (cleanTarget.contains('bahah') && (cleanInput.contains('bahah') || cleanInput.contains('الباحة'))) return true;

    return false;
  }

  // Dynamic test breakdown
  Map<String, int> getTestResultBreakdown(String testName, [int? targetYear]) {
    final Map<String, int> breakdown = {};
    final String targetTest = testName.toUpperCase().trim();

    for (var p in _filteredPatients) {
      final val = p.getLatestValue(targetTest, targetYear);
      if (val == null) continue;

      // Classify based on clinical test type
      if (targetTest.contains('HEPATITIS B VIRUS SURFACE AB') ||
          targetTest.contains('HBSAB') ||
          targetTest.contains('ANTI-HBS') ||
          targetTest.contains('ANTI - HBS') ||
          targetTest.contains('SURFACE AB')) {
        final parsed = Patient.parseValueAndUnit(val);
        final double? dVal = parsed['value'];
        final String? unit = parsed['unit'];

        if (dVal != null) {
          // Normalize unit text: strip whitespace and lowercase
          final normUnit = (unit ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');
          bool isImmune = false;

          // 10 mIU/mL equals 10000 mIU/L (since 1 mL = 0.001 L)
          if (normUnit == 'm[iu]/l' || normUnit == 'miu/l') {
            isImmune = dVal >= 10000;
          } else if (normUnit == 'miu/ml' || normUnit == 'iu/l') {
            isImmune = dVal >= 10;
          } else {
            // Default fallback
            isImmune = dVal >= 10;
          }

          final label = isImmune ? 'Positive / Reactive / Immune' : 'Negative / Non-reactive / Not immune';
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        } else {
          // Qualitative text fallback
          final strVal = val.toString().toLowerCase().trim();
          if (strVal == 'positive' || strVal == 'reactive' || strVal == 'immune' || strVal.contains('immune') || strVal.contains('reactive')) {
            breakdown['Positive / Reactive / Immune'] = (breakdown['Positive / Reactive / Immune'] ?? 0) + 1;
          } else {
            breakdown['Negative / Non-reactive / Not immune'] = (breakdown['Negative / Non-reactive / Not immune'] ?? 0) + 1;
          }
        }
      } else if (targetTest == 'ALT' || targetTest == 'AST') {
        final numVal = p.getNumericValue(targetTest, targetYear);
        if (numVal != null) {
          final label = numVal <= 40 ? 'Normal (<= 40 U/L)' : 'Elevated (> 40 U/L)';
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        }
      } else if (targetTest == 'PLATELETS' || targetTest == 'PLT') {
        final numVal = p.getNumericValue(targetTest, targetYear);
        if (numVal != null) {
          // Adjust for platelet units (normal range >= 150)
          double limit = 150;
          if (numVal > 1000) {
            limit = 150000;
          }
          final label = numVal >= limit ? 'Normal (>= 150)' : 'Low (< 150)';
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        }
      } else if (targetTest == 'HBV DNA' || targetTest == 'HBV_DNA' || targetTest == 'VIRAL LOAD' || targetTest == 'PCR') {
        final numVal = p.getNumericValue(targetTest, targetYear);
        if (numVal != null) {
          String label;
          if (numVal < 10) {
            label = 'Undetectable (< 10 IU/mL)';
          } else if (numVal < 2000) {
            label = 'Low (< 2,000 IU/mL)';
          } else if (numVal <= 20000) {
            label = 'Moderate (2,000 - 20,000)';
          } else {
            label = 'High (> 20,000 IU/mL)';
          }
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        }
      } else {
        // Qualitative / Generic test (like HBsAg, HBeAg or others)
        String label = val.toString().toLowerCase().trim();
        // Capitalize for cleaner UI
        if (label == 'positive' || label == 'reactive' || label == 'موجب') {
          label = 'Positive / Reactive';
        } else if (label == 'negative' || label == 'non-reactive' || label == 'سالب') {
          label = 'Negative / Non-reactive';
        } else {
          label = label.toUpperCase();
        }
        breakdown[label] = (breakdown[label] ?? 0) + 1;
      }
    }

    return breakdown;
  }

  // Get numerical statistics for test card (Min, Max, Mean)
  Map<String, double> getTestNumericalStats(String testName, [int? targetYear]) {
    final list = _filteredPatients
        .map((p) => p.getNumericValue(testName, targetYear))
        .whereType<double>()
        .toList();

    if (list.isEmpty) return {};

    final minVal = list.reduce((a, b) => a < b ? a : b);
    final maxVal = list.reduce((a, b) => a > b ? a : b);
    final meanVal = list.reduce((a, b) => a + b) / list.length;

    return {
      'min': double.parse(minVal.toStringAsFixed(1)),
      'max': double.parse(maxVal.toStringAsFixed(1)),
      'mean': double.parse(meanVal.toStringAsFixed(1)),
    };
  }
}
