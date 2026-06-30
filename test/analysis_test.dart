import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hepb_analyzer/models/patient_model.dart';
import 'package:hepb_analyzer/providers/analysis_provider.dart';

void main() {
  setUpAll(() async {
    // Initialize hive for tests
    Hive.init('.');
  });

  group('Hepatitis B Patient Model Tests (Simplified)', () {
    test('Age calculation relative to test year', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1995-04-12',
        region: 'Riyadh',
        testHistory: {},
      );

      expect(patient.getAgeInYear(2025), 30);
      expect(patient.getAgeInYear(2015), 20);
    });

    test('Patient testHistory extraction', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985-01-01',
        region: 'Riyadh',
        testHistory: {
          'ALT': {2025: 36.0, 2024: 30.0},
          'HBSAG': {2025: 'positive'},
        },
      );

      expect(patient.getLatestValue('ALT'), 36.0);
      expect(patient.getLatestValue('ALT', 2024), 30.0);
      expect(patient.getBooleanValue('HBsAg'), true);
      expect(patient.getLatestYear(), 2025);
    });

    test('Saudi Region Populations exist', () {
      expect(Patient.saudiRegionPopulations['Riyadh'], 8591748);
      expect(Patient.saudiRegionPopulations['Makkah'], 7769994);
      expect(Patient.saudiRegionPopulations.length, 13);
    });
  });

  group('AnalysisProvider Robust Parsing Tests', () {
    test('Parse CSV with scrambled column order and blank lines at the top', () async {
      final provider = AnalysisProvider();
      
      const csvDataWithBlanksAndScrambled = 
          "\n"
          "\n"
          "test_name,result_value,result_year,gender,dateofbirth,region_en\n"
          "ALT,45.5,2025,Male,1990,Riyadh\n"
          "AST,38.0,2025,Male,1990,Riyadh\n"
          "HBsAg,positive,2025,Female,1995,Makkah\n";

      final bytes = Uint8List.fromList(utf8.encode(csvDataWithBlanksAndScrambled));
      
      // Wait for provider to load cached boxes
      await Future.delayed(const Duration(milliseconds: 100));
      
      await provider.parseFile(bytes, 'test.csv', bytes.length);

      expect(provider.errorMessage, isNull);
      expect(provider.totalPatientsCount, 2); // 1 Male in Riyadh, 1 Female in Makkah
      expect(provider.totalUniqueTestsCount, 3); // ALT, AST, HBsAg
      expect(provider.totalRegionsCount, 2); // Riyadh, Makkah
      
      final makkahPrevalence = provider.regionAnalysisTable.firstWhere((r) => r['region'] == 'Makkah');
      expect(makkahPrevalence['patients'], 1);
    });

    test('Add record manually creates new patient or appends tests', () async {
      final provider = AnalysisProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Clear data first
      await provider.clearCache();
      
      // Add first record (creates patient)
      await provider.addManualRecord(
        gender: 'Female',
        dob: '1988',
        region: 'Jazan',
        testName: 'ALT',
        year: 2025,
        value: '35',
      );

      expect(provider.totalPatientsCount, 1);
      expect(provider.totalUniqueTestsCount, 1);
      expect(provider.allPatients.first.getNumericValue('ALT'), 35.0);

      // Add second record for the same patient (appends test)
      await provider.addManualRecord(
        gender: 'Female',
        dob: '1988',
        region: 'Jazan',
        testName: 'HBsAg',
        year: 2025,
        value: 'positive',
      );

      expect(provider.totalPatientsCount, 1); // Stays 1 patient (merged!)
      expect(provider.totalUniqueTestsCount, 2); // Now has 2 tests
      expect(provider.allPatients.first.getBooleanValue('HBsAg'), true);
    });
  });

  group('Anti-HBs/HBsAb Clinical Unit-based Interpretation Tests', () {
    const String testName = "Hepatitis B virus surface Ab [Units/volume] in Serum or Plasma by Immunoassay";

    test('Unit m[IU]/L below 10000 should be Negative/Not immune', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985',
        region: 'Riyadh',
        testHistory: {
          testName.toUpperCase(): {2025: "423 m[IU]/L"}
        },
      );
      expect(patient.getBooleanValue(testName), false);
    });

    test('Unit m[IU]/L equal or above 10000 should be Positive/Immune', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985',
        region: 'Riyadh',
        testHistory: {
          testName.toUpperCase(): {2025: "12500 m[IU]/L"}
        },
      );
      expect(patient.getBooleanValue(testName), true);
    });

    test('Unit mIU/mL below 10 should be Negative/Not immune', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985',
        region: 'Riyadh',
        testHistory: {
          testName.toUpperCase(): {2025: "8.5 mIU/mL"}
        },
      );
      expect(patient.getBooleanValue(testName), false);
    });

    test('Unit mIU/mL equal or above 10 should be Positive/Immune', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985',
        region: 'Riyadh',
        testHistory: {
          testName.toUpperCase(): {2025: "15.4 mIU/mL"}
        },
      );
      expect(patient.getBooleanValue(testName), true);
    });

    test('Unit IU/L equal or above 10 should be Positive/Immune', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985',
        region: 'Riyadh',
        testHistory: {
          testName.toUpperCase(): {2025: "22.0 IU/L"}
        },
      );
      expect(patient.getBooleanValue(testName), true);
    });

    test('Unit mIU/L below 10000 should be Negative/Not immune', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985',
        region: 'Riyadh',
        testHistory: {
          testName.toUpperCase(): {2025: "9500 mIU/L"}
        },
      );
      expect(patient.getBooleanValue(testName), false);
    });
  });

  group('Age Group Distribution Analysis Tests', () {
    test('Correctly clusters patients into Under 15, 15-29, 30-44, 45-59, 60+', () async {
      final provider = AnalysisProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      await provider.clearCache();

      // Under 15 (e.g. Born 2015, test 2025 -> Age 10)
      await provider.addManualRecord(
        gender: 'Male',
        dob: '2015',
        region: 'Riyadh',
        testName: 'ALT',
        year: 2025,
        value: 30,
      );

      // 15 - 29 (e.g. Born 2005, test 2025 -> Age 20)
      await provider.addManualRecord(
        gender: 'Female',
        dob: '2005',
        region: 'Riyadh',
        testName: 'ALT',
        year: 2025,
        value: 30,
      );

      // 30 - 44 (e.g. Born 1990, test 2025 -> Age 35)
      await provider.addManualRecord(
        gender: 'Male',
        dob: '1990',
        region: 'Riyadh',
        testName: 'ALT',
        year: 2025,
        value: 30,
      );

      // 45 - 59 (e.g. Born 1975, test 2025 -> Age 50)
      await provider.addManualRecord(
        gender: 'Female',
        dob: '1975',
        region: 'Riyadh',
        testName: 'ALT',
        year: 2025,
        value: 30,
      );

      // 60+ (e.g. Born 1960, test 2025 -> Age 65)
      await provider.addManualRecord(
        gender: 'Male',
        dob: '1960',
        region: 'Riyadh',
        testName: 'ALT',
        year: 2025,
        value: 30,
      );

      final distribution = provider.ageGroupDistribution;

      final under15 = distribution.firstWhere((g) => g['group'] == 'Under 15');
      final group15to29 = distribution.firstWhere((g) => g['group'] == '15 - 29');
      final group30to44 = distribution.firstWhere((g) => g['group'] == '30 - 44');
      final group45to59 = distribution.firstWhere((g) => g['group'] == '45 - 59');
      final group60plus = distribution.firstWhere((g) => g['group'] == '60+');

      expect(under15['count'], 1);
      expect(under15['males'], 1);
      expect(under15['females'], 0);
      expect(under15['percentage'], 20.0);

      expect(group15to29['count'], 1);
      expect(group15to29['males'], 0);
      expect(group15to29['females'], 1);
      expect(group15to29['percentage'], 20.0);

      expect(group30to44['count'], 1);
      expect(group45to59['count'], 1);
      expect(group60plus['count'], 1);
    });
  });
}
