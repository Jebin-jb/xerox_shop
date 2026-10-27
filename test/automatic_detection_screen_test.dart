import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/screens/student/automatic_detection_screen.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/document_analysis_service.dart';

void main() {
  testWidgets(
    'AutomaticDetectionScreen displays header, upload zone, and samples',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dataService = DataService();
      const profile = UserProfile(
        id: 'student-123',
        name: 'Priya Sharma',
        email: 'priya@college.ac.in',
        role: 'student',
        studentId: 'CS2026-89',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AutomaticDetectionScreen(
            dataService: dataService,
            profile: profile,
            onToggleTheme: () {},
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Verify Title & absence of marketing/subtitles
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Smart Document Analysis'), findsNothing);
      expect(
        find.text(
          'Instant AI-powered detection of total pages, color distribution, paper size, and print rates.',
        ),
        findsNothing,
      );

      // Verify Upload / Pick Document Area
      expect(find.text('Tap to Select Document'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);

      // Verify Sample documents quick chips are removed
      expect(find.text('OR TEST WITH PRE-LOADED SAMPLES'), findsNothing);

      // Pump with initialAnalysis to verify real document workflow and results
      final sampleDoc = DocumentAnalysisResult(
        fileName: 'Test_Document.pdf',
        fileSizeBytes: 2450000,
        fileExtension: 'pdf',
        analyzedAt: DateTime.now(),
        pages: List.generate(
          12,
          (i) => PageAnalysis(
            pageNumber: i + 1,
            isColor: i == 0 || i == 3,
            isBlank: i == 11,
            dimensions: 'A4 (210 × 297 mm)',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AutomaticDetectionScreen(
            dataService: dataService,
            profile: profile,
            onToggleTheme: () {},
            initialAnalysis: sampleDoc,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify detection results appear
      expect(find.text('Detection Results'), findsOneWidget);
      expect(find.text('Analysis Complete'), findsOneWidget);
      expect(find.text('Total Pages'), findsOneWidget);
      expect(find.text('Physical Sheets'), findsOneWidget);
      expect(find.text('Color Pages'), findsOneWidget);
      expect(find.text('Cost Optimizer Breakdown'), findsNothing);
      expect(find.text('Per-Page Visual Inspection'), findsOneWidget);
      expect(find.text('Print Configuration'), findsOneWidget);
      expect(find.text('Paper Type'), findsOneWidget);
      expect(find.text('Proceed to Print Order'), findsOneWidget);
    },
  );
}
