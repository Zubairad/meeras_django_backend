import 'dart:convert';
import 'package:http/http.dart' as http;

class Earthquake {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double? depth;
  final double? lat;
  final double? lng;
  final String url;

  Earthquake({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    this.depth,
    this.lat,
    this.lng,
    required this.url,
  });

  factory Earthquake.fromGeoJson(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final coords = (feature['geometry']?['coordinates'] as List?) ?? [];
    return Earthquake(
      id: feature['id'] ?? '',
      magnitude: (props['mag'] ?? 0).toDouble(),
      place: props['place'] ?? 'Unknown location',
      time: DateTime.fromMillisecondsSinceEpoch(props['time'] ?? 0),
      depth: coords.length >= 3 ? (coords[2] as num).toDouble() : null,
      lat: coords.length >= 2 ? (coords[1] as num).toDouble() : null,
      lng: coords.length >= 1 ? (coords[0] as num).toDouble() : null,
      url: props['url'] ?? '',
    );
  }

  String get severityLabel {
    if (magnitude >= 7.0) return 'Major';
    if (magnitude >= 5.0) return 'Strong';
    if (magnitude >= 3.0) return 'Moderate';
    return 'Minor';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class DisasterService {
  // USGS feeds — no API key needed
  static const String _pastHourAll =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson';
  static const String _pastDaySignificant =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/significant_day.geojson';
  static const String _pastDayMag25 =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson';

  /// Returns recent earthquakes — tries last hour first, falls back to past day
  static Future<List<Earthquake>> getRecentEarthquakes({int limit = 5}) async {
    try {
      // Try past hour first
      var quakes = await _fetchFeed(_pastHourAll);
      // If nothing in the last hour, try past day significant
      if (quakes.isEmpty) {
        quakes = await _fetchFeed(_pastDaySignificant);
      }
      // Still nothing? Try 2.5+ past day
      if (quakes.isEmpty) {
        quakes = await _fetchFeed(_pastDayMag25);
      }
      // Sort by magnitude descending
      quakes.sort((a, b) => b.magnitude.compareTo(a.magnitude));
      return quakes.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Earthquake>> _fetchFeed(String url) async {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    final features = (data['features'] as List?) ?? [];
    return features
        .map((f) => Earthquake.fromGeoJson(f as Map<String, dynamic>))
        .where((e) => e.magnitude > 0)
        .toList();
  }
}