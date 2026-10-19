import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nirbhay/models/nearby_place_model.dart';
import 'package:nirbhay/services/nearby_service.dart';

void main() {
  group('NearbyPlaceModel Unit Tests', () {
    test('Correctly parses complete place JSON', () {
      final json = {
        'id': 'osm_node_101',
        'name': 'Connaught Place Police Station',
        'category': 'police',
        'latitude': 28.6150,
        'longitude': 77.2100,
        'address': 'Baba Kharak Singh Marg, New Delhi, India',
        'phone': '+91-11-2374-7100',
        'distanceMeters': 450,
        'distanceFormatted': '450 m away',
        'openingHours': '24/7',
        'isOpen': true,
      };

      final place = NearbyPlaceModel.fromJson(json);

      expect(place.id, 'osm_node_101');
      expect(place.name, 'Connaught Place Police Station');
      expect(place.category, 'police');
      expect(place.categoryDisplayName, 'Police Station');
      expect(place.latitude, 28.6150);
      expect(place.longitude, 77.2100);
      expect(place.address, 'Baba Kharak Singh Marg, New Delhi, India');
      expect(place.phone, '+91-11-2374-7100');
      expect(place.distanceMeters, 450);
      expect(place.distanceFormatted, '450 m away');
      expect(place.openingHours, '24/7');
      expect(place.isOpen, isTrue);
      expect(place.displayStatus, 'Open Now');
      expect(place.isVerifiedOpen, isTrue);

      final map = place.toJson();
      expect(map['id'], 'osm_node_101');
      expect(map['phone'], '+91-11-2374-7100');
    });

    test('Gracefully handles missing optional fields without inventing data', () {
      final json = {
        'id': 'osm_way_202',
        'name': 'Local Chemist',
        'category': 'pharmacy',
        'latitude': 28.6200,
        'longitude': 77.2150,
        'distanceMeters': 1200,
        'distanceFormatted': '1.2 km away',
      };

      final place = NearbyPlaceModel.fromJson(json);

      expect(place.id, 'osm_way_202');
      expect(place.name, 'Local Chemist');
      expect(place.category, 'pharmacy');
      expect(place.categoryDisplayName, 'Pharmacy');
      expect(place.phone, isNull);
      expect(place.address, isNull);
      expect(place.openingHours, isNull);
      expect(place.isOpen, isNull);
      expect(place.displayStatus, 'Hours Unavailable');
      expect(place.isVerifiedOpen, isFalse);
    });

    test('Category display names and colors match required safety categories', () {
      const p = NearbyPlaceModel(
        id: '1',
        name: 'P',
        category: 'police',
        latitude: 0,
        longitude: 0,
        distanceMeters: 10,
        distanceFormatted: '10 m',
      );
      expect(p.categoryDisplayName, 'Police Station');

      const h = NearbyPlaceModel(
        id: '2',
        name: 'H',
        category: 'hospital',
        latitude: 0,
        longitude: 0,
        distanceMeters: 10,
        distanceFormatted: '10 m',
      );
      expect(h.categoryDisplayName, 'Hospital / Clinic');

      const f = NearbyPlaceModel(
        id: '3',
        name: 'F',
        category: 'fire_station',
        latitude: 0,
        longitude: 0,
        distanceMeters: 10,
        distanceFormatted: '10 m',
      );
      expect(f.categoryDisplayName, 'Fire Station');
    });
  });

  group('NearbyService Unit & Mock HTTP Tests', () {
    test('fetchNearbyPlaces parses successful 200 response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/nearby'));
        expect(request.url.queryParameters['lat'], '28.6139');
        expect(request.url.queryParameters['lng'], '77.209');
        expect(request.url.queryParameters['category'], 'police');

        final responseBody = {
          'success': true,
          'category': 'police',
          'radius': 5000,
          'count': 1,
          'userLocation': {'latitude': 28.6139, 'longitude': 77.2090},
          'places': [
            {
              'id': 'osm_node_999',
              'name': 'Tilak Marg Police Station',
              'category': 'police',
              'latitude': 28.6200,
              'longitude': 77.2200,
              'address': 'Tilak Marg, New Delhi',
              'phone': '+91-11-2338-5571',
              'distanceMeters': 850,
              'distanceFormatted': '850 m away',
              'openingHours': '24/7',
              'isOpen': true,
            }
          ],
          'attribution': 'Data © OpenStreetMap contributors, ODbL 1.0',
        };

        return http.Response(jsonEncode(responseBody), 200, headers: {'content-type': 'application/json'});
      });

      final service = NearbyService();
      final result = await service.fetchNearbyPlaces(
        lat: 28.6139,
        lng: 77.2090,
        category: 'police',
        client: mockClient,
      );

      expect(result['success'], isTrue);
      expect(result['category'], 'police');
      expect(result['count'], 1);
      final places = result['places'] as List<NearbyPlaceModel>;
      expect(places.length, 1);
      expect(places[0].name, 'Tilak Marg Police Station');
      expect(places[0].phone, '+91-11-2338-5571');
      expect(places[0].distanceMeters, 850);
    });

    test('fetchNearbyPlaces handles server 400 error cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'code': 'INVALID_CATEGORY',
            'message': 'Unsupported category.',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = NearbyService();
      final result = await service.fetchNearbyPlaces(
        lat: 28.6139,
        lng: 77.2090,
        category: 'invalid',
        client: mockClient,
      );

      expect(result['success'], isFalse);
      expect(result['code'], 'INVALID_CATEGORY');
      expect(result['message'], 'Unsupported category.');
    });

    test('fetchNearbyPlaces handles server 502/504 provider timeout cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'code': 'PROVIDER_TIMEOUT',
            'message': 'Nearby places provider timed out. Please try again.',
          }),
          504,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = NearbyService();
      final result = await service.fetchNearbyPlaces(
        lat: 28.6139,
        lng: 77.2090,
        client: mockClient,
      );

      expect(result['success'], isFalse);
      expect(result['code'], 'PROVIDER_TIMEOUT');
      expect(result['message'], contains('timed out'));
    });
  });
}
