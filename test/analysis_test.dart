import 'package:flutter_test/flutter_test.dart';
import 'package:hepb_analyzer/models/patient_model.dart';

void main() {
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
}
