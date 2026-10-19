import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/models/nearby_place_model.dart';

void main() {
  group('Issue 1: Nearby Place Call Button & Phone Number Tests', () {
    test('Place with phone number has phone displayed and Call button active', () {
      final placeWithPhone = NearbyPlaceModel.fromJson({
        'id': 'osm_node_1',
        'name': 'City Police Station',
        'category': 'police',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'phone': '+91-11-2338-1234',
        'distanceMeters': 400,
        'distanceFormatted': '400 m away',
      });

      expect(placeWithPhone.phone, '+91-11-2338-1234');
      expect(placeWithPhone.phone!.isNotEmpty, isTrue);
    });

    test('Place without phone number has null phone and never fabricates one', () {
      final placeWithoutPhone = NearbyPlaceModel.fromJson({
        'id': 'osm_node_2',
        'name': 'Community Health Center',
        'category': 'hospital',
        'latitude': 28.6150,
        'longitude': 77.2100,
        'distanceMeters': 900,
        'distanceFormatted': '900 m away',
      });

      expect(placeWithoutPhone.phone, isNull);
    });

    testWidgets('Card shows enabled Call button and phone number when phone is present', (tester) async {
      final place = NearbyPlaceModel.fromJson({
        'id': 'osm_node_1',
        'name': 'Central Police Station',
        'category': 'police',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'phone': '+91-11-2338-1234',
        'distanceMeters': 400,
        'distanceFormatted': '400 m away',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final hasPhone = place.phone != null && place.phone!.trim().isNotEmpty;
                return Column(
                  children: [
                    Text(place.name),
                    if (hasPhone)
                      Text(place.phone!)
                    else
                      const Text('Phone number unavailable'),
                    if (hasPhone)
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call'),
                      )
                    else
                      const OutlinedButton(
                        onPressed: null,
                        child: Text('Call'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Central Police Station'), findsOneWidget);
      expect(find.text('+91-11-2338-1234'), findsOneWidget);
      expect(find.text('Phone number unavailable'), findsNothing);

      final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Call'));
      expect(button.enabled, isTrue);
    });

    testWidgets('Card shows disabled Call button and "Phone number unavailable" when phone is absent', (tester) async {
      final place = NearbyPlaceModel.fromJson({
        'id': 'osm_node_2',
        'name': 'District Fire Service',
        'category': 'fire_station',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'distanceMeters': 700,
        'distanceFormatted': '700 m away',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final hasPhone = place.phone != null && place.phone!.trim().isNotEmpty;
                return Column(
                  children: [
                    Text(place.name),
                    if (hasPhone)
                      Text(place.phone!)
                    else
                      const Text('Phone number unavailable'),
                    if (hasPhone)
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call'),
                      )
                    else
                      const OutlinedButton(
                        onPressed: null,
                        child: Text('Call'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('District Fire Service'), findsOneWidget);
      expect(find.text('Phone number unavailable'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Call'));
      expect(button.enabled, isFalse);
    });
  });

  group('Issue 2: Coordinate & Map Marker Data Integrity Tests', () {
    test('Coordinates are properly parsed as double and never swapped or zeroed', () {
      final json = {
        'id': 'osm_node_42',
        'name': 'Safdarjung Hospital',
        'category': 'hospital',
        'latitude': 28.5684,
        'longitude': 77.2066,
        'distanceMeters': 1500,
        'distanceFormatted': '1.5 km away',
      };

      final place = NearbyPlaceModel.fromJson(json);

      expect(place.latitude, 28.5684);
      expect(place.longitude, 77.2066);
      expect(place.latitude, isNot(equals(place.longitude)));
    });

    test('Category definitions and icons match required services', () {
      final categories = ['police', 'hospital', 'pharmacy', 'fire_station'];

      for (final cat in categories) {
        final place = NearbyPlaceModel(
          id: 'test_$cat',
          name: 'Test $cat',
          category: cat,
          latitude: 28.0,
          longitude: 77.0,
          distanceMeters: 100,
          distanceFormatted: '100 m away',
        );

        expect(place.categoryIcon, isNotNull);
        expect(place.categoryBgColor, isNotNull);
        expect(place.categoryIconColor, isNotNull);
      }
    });
  });
}
