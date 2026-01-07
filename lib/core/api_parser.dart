class ApiParser {
  /// Mengambil list dari response yang formatnya bisa:
  /// A) { "data": [ ... ] }
  /// B) { "data": { "data": [ ... ], ...pagination } }
  static List<dynamic> extractList(dynamic resData, {String key = 'data'}) {
    if (resData is! Map) return const [];

    final raw = resData[key];

    if (raw is List) return raw;
    if (raw is Map) {
      final inner = raw['data'];
      if (inner is List) return inner;
    }
    return const [];
  }
}
