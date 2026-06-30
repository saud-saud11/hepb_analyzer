import 'package:flutter_test/flutter_test.dart';
import 'package:hepb_analyzer/models/patient_model.dart';

void main() {
  group('Hepatitis B Patient Model Tests', () {
    test('Age calculation relative to test year', () {
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1990-04-12',
        region: 'Riyadh',
        testHistory: {},
      );

      expect(patient.getAgeInYear(2025), 35);
      expect(patient.getAgeInYear(2010), 20);
    });

    test('FIB-4 score calculation formula', () {
      // Formula: (Age * AST) / (Platelets * sqrt(ALT))
      // For Age = 40, AST = 40, Platelets = 200, ALT = 36:
      // sqrt(36) = 6
      // (40 * 40) / (200 * 6) = 1600 / 1200 = 1.33
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1985-01-01', // Age 40 in 2025
        region: 'Riyadh',
        testHistory: {
          'ALT': {2025: 36.0},
          'AST': {2025: 40.0},
          'PLATELETS': {2025: 200.0}, // enters as 200 (x10^9/L)
        },
      );

      final fib4 = patient.getFib4(2025);
      expect(fib4, 1.33);
      expect(patient.getFibrosisRisk(2025), FibrosisRiskLevel.low);
    });

    test('APRI score calculation formula', () {
      // Formula: ((AST / 40.0) * 100) / Platelets
      // For AST = 60, Platelets = 150:
      // ((60 / 40) * 100) / 150 = (1.5 * 100) / 150 = 150 / 150 = 1.0
      final patient = Patient(
        gender: 'Female',
        dateOfBirth: '1990-01-01',
        region: 'Makkah',
        testHistory: {
          'AST': {2025: 60.0},
          'PLATELETS': {2025: 150.0},
        },
      );

      expect(patient.getApri(2025), 1.00);
    });

    test('EASL Disease Staging - Inactive Carrier (Phase 3)', () {
      // Inactive Carrier: HBsAg (+), HBeAg (-), ALT <= 40, HBV DNA < 2000
      final patient = Patient(
        gender: 'Male',
        dateOfBirth: '1980-01-01',
        region: 'Eastern',
        testHistory: {
          'HBSAG': {2025: 'positive'},
          'HBEAG': {2025: 'negative'},
          'ALT': {2025: 28.0},
          'HBV DNA': {2025: 120.0}, // < 2000
        },
      );

      expect(patient.getDiseasePhase(2025), HepBPhase.inactiveCarrier);
    });

    test('EASL Disease Staging - Active HBeAg-Negative Hepatitis (Phase 4)', () {
      // Active HBeAg-Negative Hepatitis: HBsAg (+), HBeAg (-), ALT > 40, HBV DNA >= 2000
      final patient = Patient(
        gender: 'Female',
        dateOfBirth: '1975-01-01',
        region: 'Riyadh',
        testHistory: {
          'HBSAG': {2025: 'positive'},
          'HBEAG': {2025: 'negative'},
          'ALT': {2025: 85.0}, // elevated
          'HBV DNA': {2025: 45000.0}, // >= 2000
        },
      );

      expect(patient.getDiseasePhase(2025), HepBPhase.activeHBeAgNegative);
    });

    test('EASL Disease Staging - Immune Tolerant (Phase 1)', () {
      // Immune Tolerant: HBsAg (+), HBeAg (+), ALT <= 40, HBV DNA very high (>= 10^7)
      final patient = Patient(
        gender: 'Female',
        dateOfBirth: '1998-01-01',
        region: 'Jazan',
        testHistory: {
          'HBSAG': {2025: 'positive'},
          'HBEAG': {2025: 'positive'},
          'ALT': {2025: 22.0}, // normal
          'HBV DNA': {2025: 250000000.0}, // very high
        },
      );

      expect(patient.getDiseasePhase(2025), HepBPhase.immuneTolerant);
    });
  });
}
