import 'package:flutter/foundation.dart';

/// PostGIS `geography(Point)` / GeoJSON / WKT / EWKB hex 를 앱 좌표로 파싱한다.
@immutable
class TtmGeoPoint {
  const TtmGeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static TtmGeoPoint? tryParse(Object? raw) {
    if (raw == null) return null;

    if (raw is Map) {
      final type = raw['type']?.toString();
      final coords = raw['coordinates'];
      if (type == 'Point' && coords is List && coords.length >= 2) {
        return _fromLngLat(coords[0], coords[1]);
      }
      if (coords is List && coords.length >= 2) {
        return _fromLngLat(coords[0], coords[1]);
      }
      final lat = raw['lat'] ?? raw['latitude'];
      final lng = raw['lng'] ?? raw['longitude'];
      if (lat != null && lng != null) {
        return _fromLngLat(lng, lat);
      }
      return null;
    }

    if (raw is List && raw.length >= 2) {
      return _fromLngLat(raw[0], raw[1]);
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;

      final wkt = RegExp(
        r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)',
        caseSensitive: false,
      ).firstMatch(s);
      if (wkt != null) {
        final lon = double.tryParse(wkt.group(1)!);
        final lat = double.tryParse(wkt.group(2)!);
        if (lat != null && lon != null) {
          return TtmGeoPoint(latitude: lat, longitude: lon);
        }
      }

      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) {
        return _tryParseEwkbHex(s);
      }
    }

    return null;
  }

  static TtmGeoPoint? _fromLngLat(Object? lngRaw, Object? latRaw) {
    if (lngRaw is! num || latRaw is! num) return null;
    return TtmGeoPoint(
      latitude: latRaw.toDouble(),
      longitude: lngRaw.toDouble(),
    );
  }

  /// PostGIS EWKB hex (Realtime·REST geography 기본 형식).
  static TtmGeoPoint? _tryParseEwkbHex(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    if (clean.length < 42 || clean.length.isOdd) return null;

    try {
      final bytes = Uint8List(clean.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }

      final le = bytes[0] == 1;
      final endian = le ? Endian.little : Endian.big;
      final data = ByteData.sublistView(bytes);

      final wkbType = data.getUint32(1, endian);
      if ((wkbType & 0xff) != 1) return null;

      var offset = 5;
      if ((wkbType & 0x20000000) != 0) {
        offset += 4;
      }

      if (bytes.length < offset + 16) return null;

      final lng = data.getFloat64(offset, endian);
      final lat = data.getFloat64(offset + 8, endian);
      if (!lat.isFinite || !lng.isFinite) return null;
      if (lat.abs() > 90 || lng.abs() > 180) return null;

      return TtmGeoPoint(latitude: lat, longitude: lng);
    } catch (_) {
      return null;
    }
  }
}
