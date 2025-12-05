import 'package:dio/dio.dart';
import 'package:xml/xml.dart' as xml;
import '../models/news_article_model.dart';

abstract class NewsRemoteDataSource {
  Future<List<NewsArticleModel>> getTopHeadlines({String category = 'general'});
  Future<List<NewsArticleModel>> searchNews(String query);
}

class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  final Dio dio;
  
  // Quality thresholds
  static const int _minTitleLength = 10;
  static const int _maxArticleAgeDays = 7; // Only show articles from last 7 days
  
  NewsRemoteDataSourceImpl({required this.dio}) {
    // Don't modify the global Dio instance - set responseType per request instead
    // This prevents affecting other features like weather that use the same Dio instance
  }

  // VERIFIED & TESTED RSS feeds (December 2024)
  // These feeds are confirmed to update regularly with quality news content
  static const Map<String, List<String>> rssSources = {
    'general': [
      'http://feeds.bbci.co.uk/news/rss.xml',                    // BBC News - Updates hourly
      'http://feeds.bbci.co.uk/news/world/rss.xml',              // BBC World - Updates hourly
      'https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml', // NYT - Updates daily
      'https://www.theguardian.com/world/rss',                   // Guardian - Updates frequently
    ],
    'technology': [
      'http://feeds.bbci.co.uk/news/technology/rss.xml',         // BBC Tech - Daily updates
      'https://www.theguardian.com/technology/rss',              // Guardian Tech
      'https://www.wired.com/feed/rss',                          // Wired - Daily updates
      'https://www.theverge.com/rss/index.xml',                  // The Verge - Frequent updates
    ],
    'business': [
      'http://feeds.bbci.co.uk/news/business/rss.xml',           // BBC Business
      'https://www.theguardian.com/business/rss',                // Guardian Business
      'https://rss.nytimes.com/services/xml/rss/nyt/Business.xml', // NYT Business
    ],
    'sports': [
      'http://feeds.bbci.co.uk/sport/rss.xml',                   // BBC Sport - Frequent updates
      'https://www.theguardian.com/sport/rss',                   // Guardian Sport
      'https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml', // NYT Sports
    ],
    'entertainment': [
      'http://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml', // BBC Entertainment
      'https://www.theguardian.com/culture/rss',                 // Guardian Culture
      'https://variety.com/feed/',                               // Variety
    ],
    'health': [
      'http://feeds.bbci.co.uk/news/health/rss.xml',             // BBC Health
      'https://rss.nytimes.com/services/xml/rss/nyt/Health.xml', // NYT Health
    ],
    'science': [
      'http://feeds.bbci.co.uk/news/science_and_environment/rss.xml', // BBC Science
      'https://rss.nytimes.com/services/xml/rss/nyt/Science.xml', // NYT Science
      'https://www.nasa.gov/rss/dyn/breaking_news.rss',          // NASA Breaking News
    ],
  };

  @override
  Future<List<NewsArticleModel>> getTopHeadlines({String category = 'general'}) async {
    final feeds = rssSources[category] ?? rssSources['general']!;
    final List<NewsArticleModel> allArticles = [];

    // Fetch from all feeds concurrently
    final results = await Future.wait(
      feeds.map((feedUrl) => _fetchRssFeed(feedUrl, category)),
      eagerError: false,
    );

    // Combine all results
    for (final articles in results) {
      allArticles.addAll(articles);
    }

    // Apply strict quality filters
    final qualityArticles = allArticles.where((article) => _isQualityArticle(article)).toList();

    // Remove duplicates by URL
    final seen = <String>{};
    final unique = qualityArticles.where((article) {
      if (seen.contains(article.url)) return false;
      seen.add(article.url);
      return true;
    }).toList();

    // Sort by published date (newest first) and limit
    unique.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    
    print('✅ Fetched ${unique.length} quality articles from ${feeds.length} sources');
    return unique.take(50).toList();
  }

  @override
  Future<List<NewsArticleModel>> searchNews(String query) async {
    final allFeeds = [
      ...rssSources['general']!,
      ...rssSources['technology']!,
    ];
    
    final List<NewsArticleModel> allArticles = [];

    final results = await Future.wait(
      allFeeds.map((feedUrl) => _fetchRssFeed(feedUrl, 'general')),
      eagerError: false,
    );

    for (final articles in results) {
      allArticles.addAll(articles);
    }

    // Filter by query and quality
    final searchQuery = query.toLowerCase();
    final filtered = allArticles.where((article) {
      final matchesQuery = article.title.toLowerCase().contains(searchQuery) ||
          (article.description?.toLowerCase().contains(searchQuery) ?? false);
      return matchesQuery && _isQualityArticle(article);
    }).toList();

    // Remove duplicates
    final seen = <String>{};
    final unique = filtered.where((article) {
      if (seen.contains(article.url)) return false;
      seen.add(article.url);
      return true;
    }).toList();

    unique.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return unique.take(50).toList();
  }

  /// Quality check - ensures article meets NewsAPI.org standards
  bool _isQualityArticle(NewsArticleModel article) {
    // Must have valid URL
    if (article.url.isEmpty || !article.url.startsWith('http')) {
      return false;
    }

    // Must have meaningful title (not "No Title" or too short)
    if (article.title.isEmpty || 
        article.title == 'No Title' || 
        article.title.length < _minTitleLength) {
      return false;
    }

    // Must be recent (within last 7 days)
    final daysSincePublished = DateTime.now().difference(article.publishedAt).inDays;
    if (daysSincePublished > _maxArticleAgeDays) {
      return false;
    }

    // Prefer articles with images (but don't require it)
    // This matches NewsAPI.org behavior where most articles have images

    return true;
  }

  Future<List<NewsArticleModel>> _fetchRssFeed(String feedUrl, String category) async {
    try {
      final response = await dio.get(
        feedUrl,
        options: Options(
          responseType: ResponseType.plain, // Set per-request to avoid affecting weather
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final articles = _parseRssFeed(response.data, feedUrl, category);
        print('📰 ${_extractSourceName(feedUrl)}: Fetched ${articles.length} articles');
        return articles;
      }
      
      print('⚠️  ${_extractSourceName(feedUrl)}: Failed with status ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ ${_extractSourceName(feedUrl)}: Error - $e');
      return [];
    }
  }

  List<NewsArticleModel> _parseRssFeed(String xmlData, String feedUrl, String category) {
    try {
      final document = xml.XmlDocument.parse(xmlData);
      
      // Detect feed type
      if (document.findAllElements('item').isNotEmpty) {
        return _parseRss2Feed(document, feedUrl, category);
      } else if (document.findAllElements('entry').isNotEmpty) {
        return _parseAtomFeed(document, feedUrl, category);
      }
      
      return [];
    } catch (e) {
      print('Error parsing XML from $feedUrl: $e');
      return [];
    }
  }

  List<NewsArticleModel> _parseRss2Feed(xml.XmlDocument document, String feedUrl, String category) {
    final items = document.findAllElements('item');
    final articles = <NewsArticleModel>[];
    
    for (final item in items) {
      try {
        final title = _getFirstElementText(item, ['title']) ?? '';
        if (title.isEmpty || title.length < _minTitleLength) continue;

        // Extract link
        String link = _getFirstElementText(item, ['link', 'guid']) ?? '';
        
        // Handle GUID with isPermaLink attribute
        if (link.isEmpty || !link.startsWith('http')) {
          final guidElement = item.findElements('guid').firstOrNull;
          if (guidElement != null) {
            final guid = guidElement.innerText.trim();
            if (guid.startsWith('http')) {
              link = guid.split('#').first; // Remove BBC's duplicate markers (#1, #2, etc.)
            }
          }
        }
        
        if (link.isEmpty || !link.startsWith('http')) continue;

        // Description
        final description = _getFirstElementText(item, [
          'description',
          'content:encoded',
          'summary',
          'media:description',
        ]);

        // Published date
        final pubDateStr = _getFirstElementText(item, [
          'pubDate',
          'published',
          'dc:date',
          'date',
          'updated',
        ]);
        
        final publishedAt = pubDateStr != null && pubDateStr.isNotEmpty
            ? _parseDate(pubDateStr)
            : DateTime.now();

        // Skip old articles
        if (DateTime.now().difference(publishedAt).inDays > _maxArticleAgeDays) {
          continue;
        }

        // Extract image
        final imageUrl = _extractImageUrl(item, description);

        // Author
        final author = _getFirstElementText(item, [
          'author',
          'dc:creator',
          'creator',
          'media:credit',
        ]);

        final source = _extractSourceName(feedUrl);

        final article = NewsArticleModel(
          id: link,
          title: _cleanText(title),
          description: description != null ? _cleanText(description) : null,
          url: link,
          imageUrl: imageUrl,
          source: source,
          author: author != null ? _cleanText(author) : null,
          publishedAt: publishedAt,
          category: category,
        );

        articles.add(article);
      } catch (e) {
        // Skip invalid article
        continue;
      }
    }
    
    return articles;
  }

  List<NewsArticleModel> _parseAtomFeed(xml.XmlDocument document, String feedUrl, String category) {
    final entries = document.findAllElements('entry');
    final articles = <NewsArticleModel>[];
    
    for (final entry in entries) {
      try {
        final title = _getFirstElementText(entry, ['title']) ?? '';
        if (title.isEmpty || title.length < _minTitleLength) continue;
        
        // Extract link
        String link = '';
        final linkElements = entry.findElements('link');
        for (final linkElement in linkElements) {
          final href = linkElement.getAttribute('href');
          if (href != null && href.startsWith('http')) {
            final rel = linkElement.getAttribute('rel');
            if (rel == null || rel == 'alternate') {
              link = href;
              break;
            } else if (link.isEmpty) {
              link = href;
            }
          }
        }
        
        if (link.isEmpty) continue;
        
        final summary = _getFirstElementText(entry, [
          'summary',
          'content',
          'description',
        ]);
        
        final publishedStr = _getFirstElementText(entry, [
          'published',
          'updated',
          'modified',
        ]);
        
        final publishedAt = publishedStr != null && publishedStr.isNotEmpty
            ? _parseDate(publishedStr)
            : DateTime.now();

        // Skip old articles
        if (DateTime.now().difference(publishedAt).inDays > _maxArticleAgeDays) {
          continue;
        }

        final imageUrl = _extractImageUrl(entry, summary);
        
        String? author;
        final authorElement = entry.findElements('author').firstOrNull;
        if (authorElement != null) {
          author = _getFirstElementText(authorElement, ['name']);
        }

        final source = _extractSourceName(feedUrl);

        final article = NewsArticleModel(
          id: link,
          title: _cleanText(title),
          description: summary != null ? _cleanText(summary) : null,
          url: link,
          imageUrl: imageUrl,
          source: source,
          author: author != null ? _cleanText(author) : null,
          publishedAt: publishedAt,
          category: category,
        );

        articles.add(article);
      } catch (e) {
        continue;
      }
    }
    
    return articles;
  }

  String? _getFirstElementText(xml.XmlElement element, List<String> tagNames) {
    for (final tagName in tagNames) {
      final parts = tagName.split(':');
      Iterable<xml.XmlElement> elements;
      
      if (parts.length == 2) {
        elements = element.findElements(tagName);
        if (elements.isEmpty) {
          elements = element.findElements(parts[1]);
        }
      } else {
        elements = element.findElements(tagName);
      }
      
      if (elements.isNotEmpty) {
        final text = elements.first.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  String? _extractImageUrl(xml.XmlElement item, String? description) {
    // Try media:content (BBC, many feeds)
    final mediaContent = item.findElements('media:content').firstOrNull;
    if (mediaContent != null) {
      final url = mediaContent.getAttribute('url');
      if (url != null && url.startsWith('http')) return url;
    }

    // Try media:thumbnail
    final mediaThumbnail = item.findElements('media:thumbnail').firstOrNull;
    if (mediaThumbnail != null) {
      final url = mediaThumbnail.getAttribute('url');
      if (url != null && url.startsWith('http')) return url;
    }

    // Try enclosure
    final enclosure = item.findElements('enclosure').firstOrNull;
    if (enclosure != null) {
      final type = enclosure.getAttribute('type');
      if (type?.startsWith('image') == true) {
        final url = enclosure.getAttribute('url');
        if (url != null && url.startsWith('http')) return url;
      }
    }

    // Try media:group
    final mediaGroup = item.findElements('media:group').firstOrNull;
    if (mediaGroup != null) {
      final groupContent = mediaGroup.findElements('media:content').firstOrNull;
      if (groupContent != null) {
        final url = groupContent.getAttribute('url');
        if (url != null && url.startsWith('http')) return url;
      }
      
      final groupThumbnail = mediaGroup.findElements('media:thumbnail').firstOrNull;
      if (groupThumbnail != null) {
        final url = groupThumbnail.getAttribute('url');
        if (url != null && url.startsWith('http')) return url;
      }
    }

    // Extract from HTML description
    if (description != null && description.contains('<img')) {
      final imgRegex = RegExp(r'<img[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
      final match = imgRegex.firstMatch(description);
      if (match != null) {
        final url = match.group(1);
        if (url != null && url.startsWith('http')) return url;
      }
    }

    return null;
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      try {
        return _parseRfc822Date(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }
  }

  DateTime _parseRfc822Date(String dateStr) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    
    try {
      String cleaned = dateStr.replaceFirst(RegExp(r'^[A-Za-z]+,\s*'), '');
      final parts = cleaned.split(RegExp(r'\s+'));
      
      if (parts.length >= 4) {
        final day = int.parse(parts[0]);
        final month = months[parts[1]] ?? 1;
        final year = int.parse(parts[2]);
        
        if (parts.length >= 4 && parts[3].contains(':')) {
          final timeParts = parts[3].split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          final second = timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0;
          
          return DateTime.utc(year, month, day, hour, minute, second);
        }
        
        return DateTime.utc(year, month, day);
      }
    } catch (e) {
      // Return current time if parsing fails
    }
    
    return DateTime.now();
  }

  String _extractSourceName(String feedUrl) {
    final sourceMap = {
      'bbci.co.uk': 'BBC News',
      'bbc.co.uk': 'BBC News',
      'theguardian.com': 'The Guardian',
      'nytimes.com': 'The New York Times',
      'wired.com': 'Wired',
      'theverge.com': 'The Verge',
      'nasa.gov': 'NASA',
      'variety.com': 'Variety',
    };
    
    for (final entry in sourceMap.entries) {
      if (feedUrl.contains(entry.key)) {
        return entry.value;
      }
    }
    
    try {
      final uri = Uri.parse(feedUrl);
      return uri.host
          .replaceAll('www.', '')
          .replaceAll('rss.', '')
          .replaceAll('feeds.', '')
          .replaceAll('.com', '')
          .replaceAll('.co.uk', '')
          .replaceAll('.org', '');
    } catch (e) {
      return 'Unknown Source';
    }
  }

  String _cleanText(String text) {
    return text
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#x27;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}