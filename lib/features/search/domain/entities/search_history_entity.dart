/// Search history entity
class SearchHistoryEntity {
  final String id;
  final String query;
  final String? url;
  final DateTime timestamp;
  final String type; // 'search' or 'url'

  SearchHistoryEntity({
    required this.id,
    required this.query,
    this.url,
    required this.timestamp,
    required this.type,
  });

  /// Convert to model
  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'url': url,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
      };

  /// Create from model
  factory SearchHistoryEntity.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntity(
        id: json['id'] as String,
        query: json['query'] as String,
        url: json['url'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: json['type'] as String,
      );
}

