class PlatformDetector {
  static bool isYouTube(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  static bool isInstagram(String url) {
    return url.contains('instagram.com');
  }

  static bool isFacebook(String url) {
    return url.contains('facebook.com') || url.contains('fb.com');
  }

  static bool isTwitter(String url) {
    return url.contains('twitter.com') || url.contains('x.com');
  }

  static bool isTikTok(String url) {
    return url.contains('tiktok.com');
  }

  static String getPlatformName(String url) {
    if (isYouTube(url)) return 'YouTube';
    if (isInstagram(url)) return 'Instagram';
    if (isFacebook(url)) return 'Facebook';
    if (isTwitter(url)) return 'Twitter';
    if (isTikTok(url)) return 'TikTok';
    return 'Other';
  }
}

