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
      expect(Patient.saudiRegionPopulations['Riyadh'], 8500000);
      expect(Patient.saudiRegionPopulations['Makkah'], 9000000);
      expect(Patient.saudiRegionPopulations.length, 13);
    });
  });

  group('AnalysisProvider CSV Parsing Tests', () {
    test('Parse CSV content correctly', () async {
      final provider = AnalysisProvider();
      
      const csvData = 
          "gender,dateofbirth,region_en,test_name,result_year,result_value\n"
          "Male,1990,Riyadh,ALT,2025,45.5\n"
          "Male,1990,Riyadh,AST,2025,38.0\n"
          "Female,1995,Makkah,HBsAg,2025,positive\n";

      final bytes = Uint8List.fromList(utf8.encode(csvData));
      
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
  });
}
