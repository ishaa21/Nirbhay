/**
 * nearbyPlacesService.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Service for querying nearby safety services (police stations, hospitals,
 * pharmacies, fire stations) and reverse geocoding using OpenStreetMap data.
 *
 * Primary Places Provider: Overpass API (Single unified query for all categories,
 * eliminating the 4 parallel requests that triggered 429 rate limits on Nominatim).
 * Secondary Fallback Provider: OpenStreetMap Nominatim API (sequential queries).
 * Reverse Geocoding: OSM Nominatim reverse endpoint with server-side caching.
 *
 * Attribution: Data © OpenStreetMap contributors, ODbL 1.0.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const OVERPASS_ENDPOINTS = [
  process.env.OVERPASS_API_URL || 'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];

const OSM_NOMINATIM_SEARCH_URL = process.env.OSM_NOMINATIM_URL || 'https://nominatim.openstreetmap.org/search';
const OSM_NOMINATIM_REVERSE_URL = process.env.OSM_REVERSE_URL || 'https://nominatim.openstreetmap.org/reverse';
const USER_AGENT = 'NirbhayWomenSafetyApp/1.0 (contact: support@nirbhay.app)';

const SUPPORTED_CATEGORIES = {
  police: 'police',
  hospital: 'hospital',
  medical: 'hospital', // alias
  pharmacy: 'pharmacy',
  fire_station: 'fire_station',
  all: 'all',
};

// In-memory cache for nearby places: `${latGrid}_${lngGrid}_${category}_${radiusGrid}` -> { timestamp, places }
const placesCache = new Map();
const PLACES_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes (safety facilities are static)

// In-memory cache for reverse geocode: `${latGrid}_${lngGrid}` -> { timestamp, data }
const reverseCache = new Map();
const REVERSE_CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes

// In-flight request deduplication map to prevent race conditions & duplicate upstream hits
const inflightPlaces = new Map();
const inflightReverse = new Map();

// In-memory sliding window rate limiter: IP -> Array of timestamps
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 40; // 40 requests per minute per IP

/**
 * Validates latitude and longitude ranges.
 */
function validateCoordinates(latitude, longitude) {
  if (latitude === undefined || latitude === null || latitude === '') {
    return 'Latitude is required.';
  }
  if (longitude === undefined || longitude === null || longitude === '') {
    return 'Longitude is required.';
  }

  const lat = Number(latitude);
  const lng = Number(longitude);

  if (isNaN(lat) || lat < -90 || lat > 90) {
    return 'Latitude must be a valid number between -90 and 90.';
  }
  if (isNaN(lng) || lng < -180 || lng > 180) {
    return 'Longitude must be a valid number between -180 and 180.';
  }

  return null;
}

/**
 * Validates and normalizes category.
 */
function normalizeCategory(category) {
  if (!category || typeof category !== 'string') {
    return 'all';
  }
  const clean = category.trim().toLowerCase();
  return SUPPORTED_CATEGORIES[clean] || null;
}

/**
 * Calculates Great-Circle distance between two coordinates using Haversine formula (in meters).
 */
function calculateDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in meters
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return Math.round(R * c);
}

/**
 * Formats distance in meters to a human-readable string (e.g. "450 m away" or "1.2 km away").
 */
function formatDistance(meters) {
  if (meters == null || isNaN(meters)) return 'Unknown distance';
  if (meters < 1000) {
    return `${meters} m away`;
  }
  const km = (meters / 1000).toFixed(1);
  return `${km} km away`;
}

/**
 * Computes bounding box (viewbox) string given center coordinate and radius in meters.
 * Returns `${left},${top},${right},${bottom}` formatted for Nominatim viewbox.
 */
function computeBoundingBox(lat, lng, radiusMeters) {
  const deltaLat = radiusMeters / 111320;
  const deltaLng = radiusMeters / (111320 * Math.cos((lat * Math.PI) / 180));

  const left = (lng - deltaLng).toFixed(5);
  const right = (lng + deltaLng).toFixed(5);
  const top = (lat + deltaLat).toFixed(5);
  const bottom = (lat - deltaLat).toFixed(5);

  return `${left},${top},${right},${bottom}`;
}

/**
 * Normalizes an OpenStreetMap element (from Overpass or Nominatim) into a structured Place record.
 */
function normalizePlaceItem(item, userLat, userLng) {
  const itemLat = parseFloat(item.lat ?? item.center?.lat);
  const itemLng = parseFloat(item.lon ?? item.center?.lon);
  if (isNaN(itemLat) || isNaN(itemLng)) return null;

  const tags = { ...(item.extratags || {}), ...(item.tags || {}) };
  const rawAmenity = (tags.amenity || item.type || '').toLowerCase();

  let category = 'other';
  let defaultName = 'Emergency Service';

  if (rawAmenity === 'police') {
    category = 'police';
    defaultName = 'Police Station';
  } else if (rawAmenity === 'hospital' || rawAmenity === 'clinic') {
    category = 'hospital';
    defaultName = rawAmenity === 'hospital' ? 'Hospital' : 'Medical Center';
  } else if (rawAmenity === 'pharmacy') {
    category = 'pharmacy';
    defaultName = 'Pharmacy';
  } else if (rawAmenity === 'fire_station') {
    category = 'fire_station';
    defaultName = 'Fire Station';
  }

  // Name: check tags.name, item.name, or first part of display_name
  const name =
    tags.name && tags.name.trim().length > 0
      ? tags.name.trim()
      : item.name && item.name.trim().length > 0
      ? item.name.trim()
      : item.display_name
      ? item.display_name.split(',')[0].trim()
      : defaultName;

  // Address
  let address = item.display_name || null;
  if (!address && (tags['addr:street'] || tags['addr:suburb'] || tags['addr:city'])) {
    const parts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:suburb'] || tags['addr:neighbourhood'],
      tags['addr:city'],
      tags['addr:postcode'],
    ].filter(Boolean);
    if (parts.length > 0) address = parts.join(', ');
  }

  // Phone extraction across common OSM tags
  let rawPhone =
    tags['contact:phone'] ||
    tags.phone ||
    tags['contact:mobile'] ||
    tags.mobile ||
    tags['emergency:phone'] ||
    tags.emergency_phone ||
    tags['phone:emergency'] ||
    tags.tel ||
    (item.address && item.address.phone) ||
    null;

  let phone = null;
  if (rawPhone && typeof rawPhone === 'string') {
    let p = rawPhone.trim();
    if (p.includes(';')) p = p.split(';')[0].trim();
    else if (p.includes('/')) p = p.split('/')[0].trim();
    else if (p.includes(',')) p = p.split(',')[0].trim();
    if ((p.match(/\d/g) || []).length >= 3) {
      phone = p;
    }
  }

  // Opening hours
  const openingHours = tags.opening_hours || item.extratags?.opening_hours || null;
  let isOpen = null;
  if (openingHours) {
    const norm = openingHours.trim().toLowerCase();
    if (norm === '24/7' || norm === '24 hours' || norm === 'open 24/7') {
      isOpen = true;
    }
  }

  const distanceMeters = calculateDistanceMeters(userLat, userLng, itemLat, itemLng);

  const osmType =
    item.osm_type ||
    (item.type === 'node' || item.type === 'way' || item.type === 'relation'
      ? item.type
      : 'node');
  const osmId = item.osm_id || item.id || item.place_id;

  return {
    id: `osm_${osmType}_${osmId}`,
    name,
    category,
    latitude: Number(itemLat.toFixed(6)),
    longitude: Number(itemLng.toFixed(6)),
    address,
    phone,
    distanceMeters,
    distanceFormatted: formatDistance(distanceMeters),
    openingHours,
    isOpen,
  };
}

/**
 * Checks in-memory sliding rate limit for client IP.
 */
function isRateLimited(clientIp) {
  if (!clientIp) return false;
  const now = Date.now();
  let timestamps = rateLimitMap.get(clientIp) || [];
  timestamps = timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);

  if (timestamps.length >= RATE_LIMIT_MAX_REQUESTS) {
    rateLimitMap.set(clientIp, timestamps);
    return true;
  }

  timestamps.push(now);
  rateLimitMap.set(clientIp, timestamps);
  return false;
}

/**
 * Native fetch with timeout via AbortController.
 */
async function fetchWithTimeout(url, options = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } finally {
    clearTimeout(id);
  }
}

/**
 * Queries Overpass API for nearby safety places using 1 single network request.
 */
async function fetchFromOverpass(lat, lng, radius, category, limit) {
  let amenityRegex = '^(police|hospital|pharmacy|fire_station)$';
  if (category && category !== 'all') {
    amenityRegex = `^(${category})$`;
  }

  const query = `[out:json][timeout:10];
(
  node["amenity"~"${amenityRegex}"](around:${radius},${lat},${lng});
  way["amenity"~"${amenityRegex}"](around:${radius},${lat},${lng});
);
out center ${limit * 2};`;

  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      const res = await fetchWithTimeout(
        endpoint,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': USER_AGENT,
            Accept: 'application/json',
          },
          body: 'data=' + encodeURIComponent(query),
        },
        9000
      );

      if (res.ok) {
        const json = await res.json();
        if (Array.isArray(json.elements)) {
          return json.elements;
        }
      } else if (res.status === 429) {
        continue; // Try secondary mirror
      }
    } catch (_) {
      // Endpoint error or timeout, continue to mirror
    }
  }

  return null; // Overpass failed, caller will use fallback
}

/**
 * Fallback: Queries Nominatim search sequentially (never in parallel) to respect OSM policies.
 */
async function fetchFromNominatim(lat, lng, radius, category, limit) {
  const viewbox = computeBoundingBox(lat, lng, radius);
  const targetCategories =
    category === 'all'
      ? ['police', 'hospital', 'pharmacy', 'fire_station']
      : [category];

  const results = [];
  const requestHeaders = {
    'User-Agent': USER_AGENT,
    Accept: 'application/json',
  };

  for (let i = 0; i < targetCategories.length; i++) {
    const cat = targetCategories[i];
    const url = `${OSM_NOMINATIM_SEARCH_URL}?format=json&amenity=${encodeURIComponent(
      cat
    )}&bounded=1&viewbox=${viewbox}&limit=${limit}&addressdetails=1&extratags=1`;

    try {
      const res = await fetchWithTimeout(url, { headers: requestHeaders }, 7000);
      if (res.ok) {
        const json = await res.json();
        if (Array.isArray(json)) {
          results.push(...json);
        }
      }
    } catch (_) {
      // Graceful category fallback
    }

    // Spacing between requests if querying multiple categories to respect 1 req/sec policy
    if (i < targetCategories.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, 800));
    }
  }

  return results;
}

/**
 * GET Nearby Places entrypoint with in-flight deduplication & multi-tiered caching.
 */
async function getNearbyPlaces({ latitude, longitude, category = 'all', radius = 5000, limit = 20, clientIp }) {
  // 1. Validation
  const coordError = validateCoordinates(latitude, longitude);
  if (coordError) {
    const err = new Error(coordError);
    err.status = 400;
    err.code = 'INVALID_COORDINATES';
    throw err;
  }

  const latNum = Number(latitude);
  const lngNum = Number(longitude);

  const cleanCategory = normalizeCategory(category);
  if (!cleanCategory) {
    const err = new Error(`Unsupported category '${category}'. Supported: police, hospital, pharmacy, fire_station, all.`);
    err.status = 400;
    err.code = 'INVALID_CATEGORY';
    throw err;
  }

  const clampedRadius = Math.min(Math.max(parseInt(radius, 10) || 5000, 500), 20000);
  const clampedLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 50);

  // 2. Client Rate Limiting
  if (clientIp && isRateLimited(clientIp)) {
    const err = new Error('Too many requests. Please wait a moment before searching again.');
    err.status = 429;
    err.code = 'RATE_LIMITED';
    throw err;
  }

  // 3. Cache lookup (~300m grid rounding)
  const latGrid = Math.round(latNum * 300) / 300;
  const lngGrid = Math.round(lngNum * 300) / 300;
  const radiusGrid = Math.round(clampedRadius / 500) * 500;
  const cacheKey = `${latGrid}_${lngGrid}_${cleanCategory}_${radiusGrid}`;

  const cachedEntry = placesCache.get(cacheKey);
  if (cachedEntry && Date.now() - cachedEntry.timestamp < PLACES_CACHE_TTL_MS) {
    const sliced = cachedEntry.places.slice(0, clampedLimit);
    return {
      success: true,
      category: cleanCategory,
      radius: clampedRadius,
      count: sliced.length,
      userLocation: { latitude: latNum, longitude: lngNum },
      places: sliced,
      attribution: 'Data © OpenStreetMap contributors, ODbL 1.0',
      cached: true,
      cacheAgeSeconds: Math.round((Date.now() - cachedEntry.timestamp) / 1000),
    };
  }

  // 4. In-flight request deduplication
  if (inflightPlaces.has(cacheKey)) {
    return await inflightPlaces.get(cacheKey);
  }

  const executeQuery = async () => {
    let rawItems = await fetchFromOverpass(latNum, lngNum, clampedRadius, cleanCategory, clampedLimit);

    // Fallback to sequential Nominatim if Overpass endpoints were unreachable
    if (!rawItems || rawItems.length === 0) {
      rawItems = await fetchFromNominatim(latNum, lngNum, clampedRadius, cleanCategory, clampedLimit);
    }

    // Normalize and deduplicate by place id
    const seenIds = new Set();
    const parsedPlaces = [];

    for (const item of rawItems || []) {
      const place = normalizePlaceItem(item, latNum, lngNum);
      if (!place) continue;
      if (seenIds.has(place.id)) continue;

      if (place.distanceMeters <= clampedRadius) {
        seenIds.add(place.id);
        parsedPlaces.push(place);
      }
    }

    parsedPlaces.sort((a, b) => a.distanceMeters - b.distanceMeters);

    // Save in cache
    placesCache.set(cacheKey, {
      timestamp: Date.now(),
      places: parsedPlaces,
    });

    if (placesCache.size > 300) {
      const firstKey = placesCache.keys().next().value;
      placesCache.delete(firstKey);
    }

    const resultPlaces = parsedPlaces.slice(0, clampedLimit);

    return {
      success: true,
      category: cleanCategory,
      radius: clampedRadius,
      count: resultPlaces.length,
      userLocation: { latitude: latNum, longitude: lngNum },
      places: resultPlaces,
      attribution: 'Data © OpenStreetMap contributors, ODbL 1.0',
      cached: false,
    };
  };

  const promise = executeQuery();
  inflightPlaces.set(cacheKey, promise);

  try {
    return await promise;
  } finally {
    inflightPlaces.delete(cacheKey);
  }
}

/**
 * Reverse Geocodes coordinates into a human-readable locality, city, and state.
 * Includes server-side caching (15-min TTL) and in-flight deduplication.
 */
async function reverseGeocode({ latitude, longitude, clientIp }) {
  const coordError = validateCoordinates(latitude, longitude);
  if (coordError) {
    const err = new Error(coordError);
    err.status = 400;
    err.code = 'INVALID_COORDINATES';
    throw err;
  }

  const latNum = Number(latitude);
  const lngNum = Number(longitude);

  if (clientIp && isRateLimited(clientIp)) {
    const err = new Error('Too many requests. Please wait a moment.');
    err.status = 429;
    err.code = 'RATE_LIMITED';
    throw err;
  }

  // Round to ~300m grid for locality caching
  const latGrid = Math.round(latNum * 300) / 300;
  const lngGrid = Math.round(lngNum * 300) / 300;
  const cacheKey = `rev_${latGrid}_${lngGrid}`;

  const cached = reverseCache.get(cacheKey);
  if (cached && Date.now() - cached.timestamp < REVERSE_CACHE_TTL_MS) {
    return {
      success: true,
      cached: true,
      latitude: latNum,
      longitude: lngNum,
      locality: cached.locality,
      city: cached.city,
      state: cached.state,
      formattedLocation: cached.formattedLocation,
    };
  }

  if (inflightReverse.has(cacheKey)) {
    return await inflightReverse.get(cacheKey);
  }

  const executeReverse = async () => {
    try {
      const url = `${OSM_NOMINATIM_REVERSE_URL}?format=json&lat=${latNum}&lon=${lngNum}&zoom=14&addressdetails=1`;
      const res = await fetchWithTimeout(
        url,
        {
          headers: {
            'User-Agent': USER_AGENT,
            Accept: 'application/json',
          },
        },
        6000
      );

      if (!res.ok) {
        throw new Error(`Reverse geocode returned ${res.status}`);
      }

      const data = await res.json();
      const addr = data.address || {};

      const locality =
        addr.suburb ||
        addr.neighbourhood ||
        addr.residential ||
        addr.subdistrict ||
        addr.quarter ||
        addr.village ||
        addr.town ||
        null;

      const city =
        addr.city ||
        addr.town ||
        addr.county ||
        addr.state_district ||
        addr.state ||
        null;

      const state = addr.state || null;

      let formattedLocation = '';
      if (locality && city && locality.toLowerCase() !== city.toLowerCase()) {
        formattedLocation = `Near ${locality}, ${city}`;
      } else if (city) {
        formattedLocation = `In ${city}`;
      } else if (locality) {
        formattedLocation = `Near ${locality}`;
      } else {
        formattedLocation = `GPS: ${latNum.toFixed(4)}, ${lngNum.toFixed(4)}`;
      }

      const payload = {
        locality,
        city,
        state,
        formattedLocation,
        timestamp: Date.now(),
      };

      reverseCache.set(cacheKey, payload);

      if (reverseCache.size > 300) {
        const firstKey = reverseCache.keys().next().value;
        reverseCache.delete(firstKey);
      }

      return {
        success: true,
        cached: false,
        latitude: latNum,
        longitude: lngNum,
        locality,
        city,
        state,
        formattedLocation,
      };
    } catch (_) {
      // Fallback gracefully to GPS coordinate string without failing the dashboard
      const fallbackLocation = `GPS: ${latNum.toFixed(4)}, ${lngNum.toFixed(4)}`;
      return {
        success: true,
        cached: false,
        isFallback: true,
        latitude: latNum,
        longitude: lngNum,
        locality: null,
        city: null,
        state: null,
        formattedLocation: fallbackLocation,
      };
    }
  };

  const promise = executeReverse();
  inflightReverse.set(cacheKey, promise);

  try {
    return await promise;
  } finally {
    inflightReverse.delete(cacheKey);
  }
}

module.exports = {
  getNearbyPlaces,
  reverseGeocode,
  validateCoordinates,
  normalizeCategory,
  calculateDistanceMeters,
  formatDistance,
  computeBoundingBox,
  normalizePlaceItem,
  SUPPORTED_CATEGORIES,
};
