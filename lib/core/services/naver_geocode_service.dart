import 'dart:convert';
import 'dart:io';

import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../config/env.dart';

/// 네이버 지도 Geocoding — 주소·장소 검색.
class NaverGeocodeService {
  const NaverGeocodeService();

  static const _host = 'maps.apigw.ntruss.com';

  bool get isConfigured {
    final secret = Env.naverMapClientSecret;
    return secret.isNotEmpty;
  }

  Future<List<NaverGeocodeHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    if (!isConfigured) {
      throw const NaverGeocodeException(
        '주소 검색 API 키가 없어요. .env.local 에 NAVER_MAP_CLIENT_SECRET 을 넣어 주세요.',
      );
    }

    final uri = Uri.https(_host, '/map-geocode/v2/geocode', {'query': q});
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set('X-NCP-APIGW-API-KEY-ID', Env.naverMapClientId);
      request.headers.set('X-NCP-APIGW-API-KEY', Env.naverMapClientSecret);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw NaverGeocodeException('검색에 실패했어요 (${response.statusCode})');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final addresses = decoded['addresses'] as List<dynamic>? ?? [];
      return [
        for (final raw in addresses)
          if (raw is Map<String, dynamic>) NaverGeocodeHit.fromJson(raw),
      ];
    } on NaverGeocodeException {
      rethrow;
    } catch (_) {
      throw const NaverGeocodeException('주소를 찾지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      client.close(force: true);
    }
  }
}

class NaverGeocodeHit {
  const NaverGeocodeHit({required this.label, required this.point});

  factory NaverGeocodeHit.fromJson(Map<String, dynamic> json) {
    final road = (json['roadAddress'] as String?)?.trim();
    final jibun = (json['jibunAddress'] as String?)?.trim();
    final label = (road?.isNotEmpty == true)
        ? road!
        : (jibun?.isNotEmpty == true
              ? jibun!
              : (json['addressElements']?.toString() ?? '검색 결과'));
    final x = double.parse(json['x'] as String);
    final y = double.parse(json['y'] as String);
    return NaverGeocodeHit(label: label, point: NLatLng(y, x));
  }

  final String label;
  final NLatLng point;
}

class NaverGeocodeException implements Exception {
  const NaverGeocodeException(this.message);
  final String message;

  @override
  String toString() => message;
}
