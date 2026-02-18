// Navi4All
// Copyright (C) Navi4All contributors
// Maintainer: Plan4Better GmbH
//
// SPDX-License-Identifier: AGPL-3.0-only
//
// Licensed under the GNU Affero General Public License, Version 3 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.gnu.org/licenses/agpl-3.0.en.html
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:navi4all/services/api.dart';
import 'package:navi4all/services/geocoding.dart';
import 'package:navi4all/services/routing.dart';
import 'package:navi4all/schemas/routing/itinerary.dart';

typedef AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

class TestHttpAdapter implements HttpClientAdapter {
  final AdapterHandler handler;

  TestHttpAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

ResponseBody jsonResponseBody(Object data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('Services layer', () {
    test('APIService uses injected Dio instance', () {
      final injectedClient = Dio(BaseOptions(baseUrl: 'https://example.test'));

      final service = APIService(apiClient: injectedClient);

      expect(service.apiClient, same(injectedClient));
      expect(service.apiClient.options.baseUrl, 'https://example.test');
    });

    test(
      'GeocodingService autocomplete sends expected query and parses data',
      () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.httpClientAdapter = TestHttpAdapter((options) async {
          captured = options;

          return jsonResponseBody({
            'timestamp': '2026-02-18T10:00:00.000Z',
            'results': [
              {
                'id': 'p1',
                'name': 'Central Station',
                'type': 'address',
                'description': 'Main station',
                'address': '1 Station Road',
                'coordinates': {'lat': 49.44, 'lon': 7.77},
              },
            ],
          }, 200);
        });

        final service = GeocodingService(apiClient: dio);
        final (timestamp, places) = await service.autocomplete(
          timestamp: '2026-02-18T09:59:59.000Z',
          query: 'central',
          focusPointLat: 49.44,
          focusPointLon: 7.77,
          limit: 4,
        );

        expect(captured?.path, '/geocoding/autocomplete');
        expect(captured?.queryParameters['query'], 'central');
        expect(captured?.queryParameters['focus_point_lat'], 49.44);
        expect(captured?.queryParameters['focus_point_lon'], 7.77);
        expect(captured?.queryParameters['limit'], 4);
        expect(timestamp.toIso8601String(), '2026-02-18T10:00:00.000Z');
        expect(places.length, 1);
        expect(places.single.name, 'Central Station');
      },
    );

    test(
      'GeocodingService autocomplete throws when status is not 200',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.httpClientAdapter = TestHttpAdapter((_) async {
          return jsonResponseBody({'timestamp': '', 'results': []}, 500);
        });

        final service = GeocodingService(apiClient: dio);

        await expectLater(
          () => service.autocomplete(
            timestamp: '2026-02-18T09:59:59.000Z',
            query: 'central',
          ),
          throwsException,
        );
      },
    );

    test(
      'RoutingService getItineraries sends payload and parses summary',
      () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.httpClientAdapter = TestHttpAdapter((options) async {
          captured = options;

          return jsonResponseBody({
            'itineraries': [
              {
                'itinerary_id': 'it-1',
                'duration': 1800,
                'start_time': '2026-02-18T10:00:00.000Z',
                'end_time': '2026-02-18T10:30:00.000Z',
                'origin': {'lat': 49.44, 'lon': 7.77},
                'destination': {'lat': 49.45, 'lon': 7.78},
                'legs': [
                  {
                    'mode': 'WALK',
                    'duration': 600,
                    'distance': 700,
                    'ratio': 1.0,
                    'geometry': 'abc',
                  },
                ],
              },
            ],
          }, 200);
        });

        final service = RoutingService(
          apiClient: dio,
          routingEngine: 'test-engine',
        );
        final results = await service.getItineraries(
          originLat: 49.44,
          originLon: 7.77,
          destinationLat: 49.45,
          destinationLon: 7.78,
          time: DateTime.utc(2026, 2, 18, 10, 0, 0),
          timeIsArrival: true,
          transportModes: const ['WALK'],
          walkingSpeed: 5.0,
          walkingAvoid: false,
          bicycleSpeed: 15.0,
          accessible: true,
          guidanceLanguage: 'en-US',
        );

        expect(captured?.path, '/routing/plan');
        expect(captured?.method, 'POST');
        expect(captured?.queryParameters['engine'], 'test-engine');
        expect(captured?.data['origin']['lat'], 49.44);
        expect(captured?.data['destination']['lon'], 7.78);
        expect(captured?.data['time_is_arrival'], true);
        expect(captured?.data['walk']['speed'], 5.0);
        expect(captured?.data['bicycle']['speed'], 15.0);
        expect(captured?.data['accessible'], true);
        expect(captured?.data['summarized'], true);

        expect(results.length, 1);
        expect((results.single as ItinerarySummary).itineraryId, 'it-1');
      },
    );

    test(
      'RoutingService getItinerariesDetailed parses detailed itineraries',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.httpClientAdapter = TestHttpAdapter((_) async {
          return jsonResponseBody({
            'itineraries': [
              {
                'itinerary_id': 'it-2',
                'duration': 1200,
                'start_time': '2026-02-18T10:00:00.000Z',
                'end_time': '2026-02-18T10:20:00.000Z',
                'origin': {'lat': 49.44, 'lon': 7.77},
                'destination': {'lat': 49.45, 'lon': 7.78},
                'legs': [
                  {
                    'start_time': '2026-02-18T10:00:00.000Z',
                    'end_time': '2026-02-18T10:20:00.000Z',
                    'mode': 'WALK',
                    'duration': 1200,
                    'distance': 1400,
                    'geometry': 'xyz',
                    'steps': [
                      {
                        'distance': 120.0,
                        'lat': 49.4401,
                        'lon': 7.7701,
                        'relative_direction': 'DEPART',
                        'absolute_direction': 'NORTH',
                        'street_name': 'Main St',
                        'bogus_name': false,
                      },
                    ],
                  },
                ],
              },
            ],
          }, 200);
        });

        final service = RoutingService(
          apiClient: dio,
          routingEngine: 'test-engine',
        );
        final details = await service.getItinerariesDetailed(
          originLat: 49.44,
          originLon: 7.77,
          destinationLat: 49.45,
          destinationLon: 7.78,
          time: DateTime.utc(2026, 2, 18, 10, 0, 0),
          transportModes: const ['WALK'],
          guidanceLanguage: 'en-US',
        );

        expect(details.length, 1);
        expect(details.single.itineraryId, 'it-2');
        expect(details.single.legs.single.steps.single.streetName, 'Main St');
      },
    );

    test(
      'RoutingService getItineraryDetails calls itinerary endpoint',
      () async {
        RequestOptions? captured;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
        dio.httpClientAdapter = TestHttpAdapter((options) async {
          captured = options;

          return jsonResponseBody({
            'itinerary_id': 'it-3',
            'duration': 900,
            'start_time': '2026-02-18T10:00:00.000Z',
            'end_time': '2026-02-18T10:15:00.000Z',
            'origin': {'lat': 49.44, 'lon': 7.77},
            'destination': {'lat': 49.45, 'lon': 7.78},
            'legs': [
              {
                'start_time': '2026-02-18T10:00:00.000Z',
                'end_time': '2026-02-18T10:15:00.000Z',
                'mode': 'WALK',
                'duration': 900,
                'distance': 1000,
                'geometry': 'xyz',
                'steps': [
                  {
                    'distance': 80.0,
                    'lat': 49.4401,
                    'lon': 7.7701,
                    'relative_direction': 'DEPART',
                    'absolute_direction': 'NORTH',
                    'street_name': 'Main St',
                    'bogus_name': false,
                  },
                ],
              },
            ],
          }, 200);
        });

        final service = RoutingService(
          apiClient: dio,
          routingEngine: 'test-engine',
        );
        final details = await service.getItineraryDetails(itineraryId: 'it-3');

        expect(captured?.path, '/routing/itinerary/it-3');
        expect(captured?.queryParameters['engine'], 'test-engine');
        expect(details.itineraryId, 'it-3');
      },
    );

    test('RoutingService throws on non-200 planning response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = TestHttpAdapter((_) async {
        return jsonResponseBody({'itineraries': []}, 500);
      });

      final service = RoutingService(
        apiClient: dio,
        routingEngine: 'test-engine',
      );

      await expectLater(
        () => service.getItineraries(
          originLat: 49.44,
          originLon: 7.77,
          destinationLat: 49.45,
          destinationLon: 7.78,
          time: DateTime.utc(2026, 2, 18, 10, 0, 0),
          transportModes: const ['WALK'],
          guidanceLanguage: 'en-US',
        ),
        throwsException,
      );
    });
  });
}
