import 'dart:io';
import 'dart:math';
import 'package:excel/excel.dart';

void main() async {
  print('Generating 50,000 mock patient records...');

  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  // Add header
  sheet.appendRow([
    TextCellValue('gender'),
    TextCellValue('dateofbirth'),
    TextCellValue('region_en'),
    TextCellValue('test_name'),
    TextCellValue('result_year'),
    TextCellValue('result_value')
  ]);

  final List<String> regions = [
    'Riyadh',
    'Makkah',
    'Madinah',
    'Eastern Province',
    'Al-Qassim',
    'Ha\'il',
    'Tabuk',
    'Al-Jawf',
    'Northern Borders',
    'Jazan',
    'Asir',
    'Najran',
    'Al-Bahah'
  ];

  final List<String> genders = ['Male', 'Female'];
  final random = Random();

  // We want to generate ~50,000 rows.
  // Each patient has ~5 rows of test results (HBsAg, ALT, AST, Platelets, HBV DNA).
  // So we generate 10,000 distinct patients.
  int totalPatients = 10000;
  int rowCount = 0;

  for (int i = 0; i < totalPatients; i++) {
    final gender = genders[random.nextInt(2)];
    
    // Generate birthdate
    final birthYear = 1950 + random.nextInt(56); // 1950 to 2005
    final birthMonth = 1 + random.nextInt(12);
    final birthDay = 1 + random.nextInt(28);
    final String dob = '$birthYear-${birthMonth.toString().padLeft(2, '0')}-${birthDay.toString().padLeft(2, '0')}';
    
    final region = regions[random.nextInt(regions.length)];
    final testYear = 2023 + random.nextInt(3); // 2023, 2024, 2025

    // Patient status clinical generation (some active hepatitis, some inactive carrier, some uninfected)
    final profileType = random.nextInt(10); // 0-9

    bool hbsagPositive = true;
    bool hbeagPositive = false;
    double alt = 25.0;
    double ast = 22.0;
    double platelets = 220.0;
    double hbvDna = 50.0;

    if (profileType == 0) {
      // Immune tolerant (Phase 1)
      hbsagPositive = true;
      hbeagPositive = true;
      alt = 15.0 + random.nextInt(20); // normal
      ast = 15.0 + random.nextInt(20);
      platelets = 180.0 + random.nextInt(150);
      hbvDna = 150000000.0 + random.nextInt(100000000); // extremely high
    } else if (profileType <= 2) {
      // HBeAg positive Active Hepatitis (Phase 2)
      hbsagPositive = true;
      hbeagPositive = true;
      alt = 45.0 + random.nextInt(150); // elevated
      ast = 40.0 + random.nextInt(100);
      platelets = 130.0 + random.nextInt(100);
      hbvDna = 50000.0 + random.nextInt(50000000);
    } else if (profileType <= 6) {
      // Inactive carrier (Phase 3)
      hbsagPositive = true;
      hbeagPositive = false;
      alt = 15.0 + random.nextInt(25); // normal
      ast = 15.0 + random.nextInt(25);
      platelets = 160.0 + random.nextInt(160);
      hbvDna = 20.0 + random.nextInt(1800); // < 2000
    } else if (profileType == 7) {
      // HBeAg negative Active Hepatitis (Phase 4)
      hbsagPositive = true;
      hbeagPositive = false;
      alt = 45.0 + random.nextInt(120); // elevated
      ast = 40.0 + random.nextInt(90);
      platelets = 110.0 + random.nextInt(90); // slightly low
      hbvDna = 2500.0 + random.nextInt(500000); // >= 2000
    } else {
      // Uninfected / Susceptible or Vaccinated
      hbsagPositive = false;
    }

    // Append rows
    // Row 1: HBsAg
    sheet.appendRow([
      TextCellValue(gender),
      TextCellValue(dob),
      TextCellValue(region),
      TextCellValue('HBsAg'),
      TextCellValue(testYear.toString()),
      TextCellValue(hbsagPositive ? 'positive' : 'negative')
    ]);
    rowCount++;

    if (hbsagPositive) {
      // Row 2: HBeAg
      sheet.appendRow([
        TextCellValue(gender),
        TextCellValue(dob),
        TextCellValue(region),
        TextCellValue('HBeAg'),
        TextCellValue(testYear.toString()),
        TextCellValue(hbeagPositive ? 'positive' : 'negative')
      ]);
      rowCount++;

      // Row 3: ALT
      sheet.appendRow([
        TextCellValue(gender),
        TextCellValue(dob),
        TextCellValue(region),
        TextCellValue('ALT'),
        TextCellValue(testYear.toString()),
        TextCellValue(alt.toInt().toString())
      ]);
      rowCount++;

      // Row 4: AST
      sheet.appendRow([
        TextCellValue(gender),
        TextCellValue(dob),
        TextCellValue(region),
        TextCellValue('AST'),
        TextCellValue(testYear.toString()),
        TextCellValue(ast.toInt().toString())
      ]);
      rowCount++;

      // Row 5: Platelets
      sheet.appendRow([
        TextCellValue(gender),
        TextCellValue(dob),
        TextCellValue(region),
        TextCellValue('Platelets'),
        TextCellValue(testYear.toString()),
        TextCellValue(platelets.toInt().toString())
      ]);
      rowCount++;

      // Row 6: HBV DNA
      sheet.appendRow([
        TextCellValue(gender),
        TextCellValue(dob),
        TextCellValue(region),
        TextCellValue('HBV DNA'),
        TextCellValue(testYear.toString()),
        TextCellValue(hbvDna.toInt().toString())
      ]);
      rowCount++;
    } else {
      // Row 2: Anti-HBs (Vaccinated check)
      final vaccinated = random.nextBool();
      sheet.appendRow([
        TextCellValue(gender),
        TextCellValue(dob),
        TextCellValue(region),
        TextCellValue('Anti-HBs'),
        TextCellValue(testYear.toString()),
        TextCellValue(vaccinated ? 'positive' : 'negative')
      ]);
      rowCount++;
    }

    if (rowCount >= 50000) {
      break;
    }
  }

  print('Writing Excel to disk...');
  final fileBytes = excel.save();
  if (fileBytes != null) {
    final file = File('hepb_50k_mock_data.xlsx');
    await file.writeAsBytes(fileBytes);
    print('Successfully generated 50,000 rows at: ${file.absolute.path}');
  } else {
    print('Error: Failed to save Excel file bytes.');
  }
}
