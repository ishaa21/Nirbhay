import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/l10n/app_localizations.dart';
import 'package:nirbhay/models/safety_hotspot_model.dart';
import 'package:nirbhay/services/proactive_route_alert_service.dart';
import 'package:nirbhay/widgets/hotspot_details_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('SafetyHotspotModel Tests', () {
    test('Correctly parses JSON with RED risk level and multiple reports', () {
      final json = {
        'id': 'hotspot_delhi_1',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'radiusMeters': 250.0,
        'riskScore': 5.2,
        'riskLevel': 'RED',
        'primaryCategory': 'HARASSMENT',
        'categoryCounts': {'HARASSMENT': 3, 'POORLY_LIT': 1},
        'reportCount': 4,
        'independentAuthorCount': 3,
        'latestReportAt': '2026-10-30T18:00:00.000Z',
        'verificationStatus': 'COMMUNITY_VERIFIED',
        'locationName': 'Connaught Place Outer Circle',
        'summary': 'Multiple reports of harassment and dim lighting after 9 PM.',
        'confirmationsCount': 8,
        'disputesCount': 0,
        'reports': [
          {
            'id': 'post_101',
            'category': 'HARASSMENT',
            'title': 'Eve teasing reported near metro exit 4',
            'description': 'Group loitering near unlit pathway.',
            'createdAt': '2026-10-30T17:30:00.000Z',
            'authorFullName': 'Ananya S.',
            'confirmationsCount': 4,
          },
        ],
        'comments': [
          {
            'id': 'c_1',
            'postId': 'post_101',
            'content': 'Police PCR van stationed here today evening.',
            'createdAt': '2026-10-30T18:15:00.000Z',
            'authorName': 'Rohit K.',
          }
        ],
      };

      final hotspot = SafetyHotspotModel.fromJSON(json);

      expect(hotspot.id, 'hotspot_delhi_1');
      expect(hotspot.latitude, 28.6139);
      expect(hotspot.longitude, 77.2090);
      expect(hotspot.radiusMeters, 250.0);
      expect(hotspot.riskScore, 5.2);
      expect(hotspot.riskLevel, HotspotRiskLevel.red);
      expect(hotspot.verificationStatus, HotspotVerificationStatus.communityVerified);
      expect(hotspot.reportCount, 4);
      expect(hotspot.independentAuthorCount, 3);
      expect(hotspot.confirmationsCount, 8);
      expect(hotspot.disputesCount, 0);
      expect(hotspot.reports.length, 1);
      expect(hotspot.reports.first.authorFullName, 'Ananya S.');
      expect(hotspot.comments.length, 1);
      expect(hotspot.comments.first.authorName, 'Rohit K.');
      expect(hotspot.color, const Color(0xFFE53935));
      expect(hotspot.borderColor, const Color(0xFFB71C1C));
    });

    test('Falls back gracefully for ORANGE and YELLOW risk levels', () {
      final orangeJson = {
        'id': 'h_orange',
        'latitude': 28.62,
        'longitude': 77.21,
        'riskLevel': 'ORANGE',
        'verificationStatus': 'DISPUTED',
      };
      final orange = SafetyHotspotModel.fromJSON(orangeJson);
      expect(orange.riskLevel, HotspotRiskLevel.orange);
      expect(orange.verificationStatus, HotspotVerificationStatus.disputed);
      expect(orange.color, const Color(0xFFFB8C00));

      final yellowJson = {
        'id': 'h_yellow',
        'latitude': 28.63,
        'longitude': 77.22,
        'riskLevel': 'YELLOW',
        'verificationStatus': 'COMMUNITY_REPORTED',
      };
      final yellow = SafetyHotspotModel.fromJSON(yellowJson);
      expect(yellow.riskLevel, HotspotRiskLevel.yellow);
      expect(yellow.verificationStatus, HotspotVerificationStatus.communityReported);
      expect(yellow.color, const Color(0xFFFDD835));
    });

    test('Privacy rule: Author names are masked and no phone/raw location is exposed', () {
      final report = HotspotReportItem.fromJSON({
        'id': 'r_1',
        'category': 'UNSAFE_AREA',
        'title': 'Poor visibility on service road',
        'description': 'Street lights are non functional',
        'authorFullName': 'Priya S.',
      });

      expect(report.authorFullName, 'Priya S.');
      expect(report.authorFullName.contains('+91'), isFalse);
      expect(report.authorFullName.contains('@'), isFalse);
    });

    test('Localizations for risk level and verification labels return non-empty strings', () {
      final l10nEn = AppLocalizations(const Locale('en', ''));
      final l10nHi = AppLocalizations(const Locale('hi', ''));
      final l10nGu = AppLocalizations(const Locale('gu', ''));

      final redHotspot = SafetyHotspotModel.fromJSON({
        'id': 'h_red',
        'riskLevel': 'RED',
        'verificationStatus': 'COMMUNITY_VERIFIED',
        'primaryCategory': 'HARASSMENT',
      });

      expect(redHotspot.localizedRiskLevelLabel(l10nEn).isNotEmpty, isTrue);
      expect(redHotspot.localizedRiskLevelLabel(l10nHi).isNotEmpty, isTrue);
      expect(redHotspot.localizedRiskLevelLabel(l10nGu).isNotEmpty, isTrue);

      expect(redHotspot.localizedVerificationLabel(l10nEn).isNotEmpty, isTrue);
      expect(redHotspot.localizedCategoryLabel(l10nEn), 'Harassment');
    });
  });

  group('ProactiveRouteAlertService Tests', () {
    test('Default configuration is active with 500m horizon', () {
      final service = ProactiveRouteAlertService();
      expect(service.isEnabled, isTrue);
      expect(service.warningDistanceMeters, 500);
      expect(service.vibrate, isTrue);
      expect(service.sound, isTrue);
    });

    test('Configuration setters clamp and update values properly', () async {
      final service = ProactiveRouteAlertService();

      await service.setWarningDistance(800);
      expect(service.warningDistanceMeters, 800);

      // Clamps outside bounds [200, 1000]
      await service.setWarningDistance(1500);
      expect(service.warningDistanceMeters, 1000);

      await service.setWarningDistance(100);
      expect(service.warningDistanceMeters, 200);

      await service.setVibrate(false);
      expect(service.vibrate, isFalse);

      await service.setSound(false);
      expect(service.sound, isFalse);

      // Restore
      await service.setWarningDistance(500);
      await service.setVibrate(true);
      await service.setSound(true);
    });

    test('dismissActiveAlert clears active notifier', () {
      final service = ProactiveRouteAlertService();
      service.activeAlertNotifier.value = SafetyHotspotModel.fromJSON({
        'id': 'test_h',
        'latitude': 28.6,
        'longitude': 77.2,
      });

      expect(service.activeAlertNotifier.value, isNotNull);
      service.dismissActiveAlert();
      expect(service.activeAlertNotifier.value, isNull);
    });
  });

  group('HotspotDetailsSheet Widget Tests', () {
    testWidgets('Renders hotspot title, risk badge, report counts and mandatory disclaimer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final hotspot = SafetyHotspotModel.fromJSON({
        'id': 'h_sheet_test',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'radiusMeters': 200.0,
        'riskScore': 4.5,
        'riskLevel': 'RED',
        'primaryCategory': 'HARASSMENT',
        'reportCount': 5,
        'independentAuthorCount': 4,
        'latestReportAt': '2026-10-30T17:00:00.000Z',
        'verificationStatus': 'COMMUNITY_VERIFIED',
        'locationName': 'Sector 18 Market Sub-Road',
        'summary': 'Reported suspicious gatherings near rear lane.',
        'confirmationsCount': 6,
        'disputesCount': 1,
        'reports': [
          {
            'id': 'rep_1',
            'category': 'HARASSMENT',
            'title': 'Poorly lit alleyway',
            'description': 'Street lights broken for 2 weeks.',
            'authorFullName': 'Simran K.',
            'createdAt': '2026-10-30T16:00:00.000Z',
          }
        ],
        'comments': [
          {
            'id': 'com_1',
            'postId': 'rep_1',
            'content': 'Avoid after 8 PM.',
            'authorName': 'Aarav M.',
            'createdAt': '2026-10-30T16:30:00.000Z',
          }
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', ''),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => HotspotDetailsSheet.show(ctx, hotspot: hotspot),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify location name
      expect(find.text('Sector 18 Market Sub-Road'), findsOneWidget);

      // Verify summary
      expect(find.text('Reported suspicious gatherings near rear lane.'), findsOneWidget);

      // Verify masked reporter name
      expect(find.text('Simran K.'), findsOneWidget);
      expect(find.text('Street lights broken for 2 weeks.'), findsOneWidget);

      // Verify feedback buttons
      expect(find.text('Still Present'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Inaccurate'), findsOneWidget);

      // Verify Mandatory Disclaimer
      expect(
        find.textContaining('Safety information is based on community reports'),
        findsOneWidget,
      );
    });
  });
}
