# API Keys Setup Guide

Complete guide for obtaining and configuring API keys for Void Browser.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Required API Keys](#required-api-keys)
3. [Optional API Keys](#optional-api-keys)
4. [Setup Instructions](#setup-instructions)
5. [Testing API Keys](#testing-api-keys)
6. [Troubleshooting](#troubleshooting)

---

## Overview

Void Browser uses several third-party APIs for its discovery features. Some require API keys (free tier available), while others are completely free.

**Total Cost**: $0 (All APIs have free tiers)

---

## Required API Keys

### 1. GNews API (News Feature)

**Purpose**: Provides news headlines and articles for the News tab and Discovery panel.

**Free Tier**:
- 100 requests/day
- 1 request/second rate limit
- Perfect for personal use and small apps

**Setup Steps**:

1. **Sign Up**:
   - Go to [GNews.io](https://gnews.io/)
   - Click "Sign Up" or "Get API Key"
   - Create a free account

2. **Get API Key**:
   - After signing up, go to your dashboard
   - Copy your API key (starts with something like `abc123def456...`)

3. **Add to .env**:
   ```env
   GNEWS_API_KEY=your_api_key_here
   ```

**Alternative**: If you prefer other news APIs:
- **NewsAPI.org**: Free tier (100 requests/day)
- **NewsData.io**: Free tier (200 requests/day)

**Note**: You may need to update `lib/core/constants/api_constants.dart` if using a different API.

---

### 2. Unsplash API (Images Feature)

**Purpose**: Provides beautiful, high-quality images for the Images tab.

**Free Tier**:
- 50 requests/hour
- Unlimited requests/month (with rate limiting)
- Perfect for personal use

**Setup Steps**:

1. **Create Account**:
   - Go to [Unsplash Developers](https://unsplash.com/developers)
   - Click "Register as a developer"
   - Sign up with your Unsplash account (or create one)

2. **Create Application**:
   - Go to [Your Applications](https://unsplash.com/oauth/applications)
   - Click "New Application"
   - Fill in:
     - **Application name**: Void Browser
     - **Description**: Mobile browser app
     - **Website**: Your website or GitHub repo
   - Accept terms and create

3. **Get Access Key**:
   - After creating the app, you'll see:
     - **Access Key**: This is your `UNSPLASH_ACCESS_KEY`
     - **Secret Key**: Not needed for this app
   - Copy the Access Key

4. **Add to .env**:
   ```env
   UNSPLASH_ACCESS_KEY=your_access_key_here
   ```

**Rate Limits**:
- 50 requests per hour
- If exceeded, wait 1 hour or upgrade to paid plan

---

## Optional API Keys

### Weather API (Open-Meteo)

**Status**: ✅ **No API Key Required**

**Purpose**: Provides weather forecasts for the Weather card.

**Setup**: Nothing needed! The app uses Open-Meteo's free API without authentication.

**Rate Limits**: 
- 10,000 requests/day (more than enough)
- No API key required

---

### Recipes API (TheMealDB)

**Status**: ✅ **No API Key Required**

**Purpose**: Provides recipe data for the Recipes section.

**Setup**: Nothing needed! TheMealDB is completely free and open.

**Rate Limits**: 
- No official limits
- Be respectful with request frequency

---

## Setup Instructions

### Step 1: Create .env File

1. Copy the template:
   ```bash
   cp ENV_FILE_TEMPLATE.txt .env
   ```

2. Or create manually:
   ```bash
   touch .env
   ```

### Step 2: Add API Keys

Edit `.env` file:

```env
# NEWS API - Required for News Feature
GNEWS_API_KEY=your_gnews_api_key_here

# UNSPLASH API - Required for Images Feature
UNSPLASH_ACCESS_KEY=your_unsplash_access_key_here

# NOTE: TheMealDB and Open-Meteo are completely FREE and don't require API keys!
```

### Step 3: Verify File Location

Ensure `.env` is in the root directory:

```
void_browser/
├── .env          ← Should be here
├── lib/
├── android/
└── pubspec.yaml
```

### Step 4: Add .env to .gitignore

**Important**: Never commit your `.env` file to version control!

Add to `.gitignore`:

```
.env
.env.local
.env.*.local
```

### Step 5: Load Environment Variables

The app uses `flutter_dotenv` to load environment variables. This is already configured in `lib/main.dart`.

**Verify loading** in `lib/main.dart`:

```dart
await dotenv.load(fileName: ".env");
```

---

## Testing API Keys

### Test GNews API

1. **Manual Test**:
   ```bash
   curl "https://gnews.io/api/v4/top-headlines?token=YOUR_API_KEY&lang=en"
   ```

2. **In App**:
   - Run the app
   - Navigate to News tab
   - Check if news articles load

### Test Unsplash API

1. **Manual Test**:
   ```bash
   curl "https://api.unsplash.com/photos/random?client_id=YOUR_ACCESS_KEY"
   ```

2. **In App**:
   - Run the app
   - Navigate to Images tab
   - Check if images load

### Test Weather API

1. **Manual Test**:
   ```bash
   curl "https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current_weather=true"
   ```

2. **In App**:
   - Run the app
   - Check Discovery page
   - Weather card should show current weather

### Test Recipes API

1. **Manual Test**:
   ```bash
   curl "https://www.themealdb.com/api/json/v1/1/random.php"
   ```

2. **In App**:
   - Run the app
   - Check Discovery page
   - Recipes section should show random recipes

---

## Troubleshooting

### Issue: "API key not found"

**Solution**:
1. Verify `.env` file exists in root directory
2. Check API key variable names match exactly:
   - `GNEWS_API_KEY` (not `GNews_API_KEY` or `gnews_api_key`)
   - `UNSPLASH_ACCESS_KEY` (not `UNSPLASH_KEY` or `unsplash_access_key`)
3. Restart the app after adding keys

### Issue: "Rate limit exceeded"

**GNews**:
- Wait 24 hours for daily limit reset
- Or upgrade to paid plan ($99/month for 10,000 requests/day)

**Unsplash**:
- Wait 1 hour for hourly limit reset
- Or upgrade to paid plan ($20/month for higher limits)

### Issue: "Invalid API key"

**GNews**:
1. Verify key is copied correctly (no extra spaces)
2. Check key is active in GNews dashboard
3. Ensure you're using the correct endpoint

**Unsplash**:
1. Verify Access Key (not Secret Key)
2. Check application is approved in Unsplash dashboard
3. Ensure key hasn't been revoked

### Issue: "No data showing"

**Check**:
1. API keys are correctly set in `.env`
2. App is restarted after adding keys
3. Internet connection is working
4. API service is not down (check status pages)

**Debug Steps**:
1. Check console logs for API errors
2. Test API endpoints manually with curl
3. Verify API keys in API provider dashboards

---

## API Provider Links

- **GNews**: [https://gnews.io/](https://gnews.io/)
- **Unsplash**: [https://unsplash.com/developers](https://unsplash.com/developers)
- **Open-Meteo**: [https://open-meteo.com/](https://open-meteo.com/)
- **TheMealDB**: [https://www.themealdb.com/](https://www.themealdb.com/)

---

## Security Best Practices

1. **Never commit `.env` file** to version control
2. **Use environment variables** in CI/CD pipelines
3. **Rotate API keys** periodically
4. **Monitor API usage** in provider dashboards
5. **Set up rate limiting** in your app
6. **Use different keys** for development and production

---

## Cost Estimation

**Free Tier Usage** (Typical):
- GNews: 100 requests/day = $0/month
- Unsplash: 50 requests/hour = $0/month
- Open-Meteo: Free = $0/month
- TheMealDB: Free = $0/month

**Total**: $0/month ✅

**If You Exceed Free Tiers**:
- GNews: $99/month (10,000 requests/day)
- Unsplash: $20/month (higher limits)
- Open-Meteo: Free (generous limits)
- TheMealDB: Free (no limits)

---

## Alternative APIs

If you want to use different APIs:

### News Alternatives:
- **NewsAPI.org**: [https://newsapi.org/](https://newsapi.org/)
- **NewsData.io**: [https://newsdata.io/](https://newsdata.io/)
- **NewsAPI.ai**: [https://newsapi.ai/](https://newsapi.ai/)

### Images Alternatives:
- **Pexels API**: [https://www.pexels.com/api/](https://www.pexels.com/api/)
- **Pixabay API**: [https://pixabay.com/api/docs/](https://pixabay.com/api/docs/)

**Note**: You'll need to update the API endpoints in `lib/core/constants/api_constants.dart` and the data models accordingly.

---

## Quick Reference

```env
# Required API Keys
GNEWS_API_KEY=your_gnews_key_here
UNSPLASH_ACCESS_KEY=your_unsplash_key_here

# Free APIs (No keys needed)
# - Open-Meteo (Weather)
# - TheMealDB (Recipes)
```

---

**Need Help?** Open an issue on GitHub or check the [Troubleshooting](#troubleshooting) section.

