import 'package:hive/hive.dart';

part 'search_history_model.g.dart';

@HiveType(typeId: 2)
class SearchHistoryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String query;

  @HiveField(2)
  final String? url; // If it was a URL navigation

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String type; // 'search' or 'url'

  SearchHistoryModel({
    required this.id,
    required this.query,
    this.url,
    required this.timestamp,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'url': url,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
      };

  factory SearchHistoryModel.fromJson(Map<String, dynamic> json) =>
      SearchHistoryModel(
        id: json['id'] as String,
        query: json['query'] as String,
        url: json['url'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: json['type'] as String,
      );
}

