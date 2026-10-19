/**
 * nearbyPlacesService.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Service for querying nearby safety services (police stations, hospitals,
 * pharmacies, fire stations) using OpenStreetMap data.
 *
 * Provider: OpenStreetMap (OSM Nominatim API)
 * - Zero external cost & no credit card/billing required.
 * - Global coverage for police, hospitals, pharmacies, and fire stations.
 * - Precise bounding box calculations and Haversine distance filtering.
 * - In-memory cache (60s TTL) to prevent repeated network queries.
 * - In-memory sliding rate limiter per client IP.
 * - Strict field normalization (never inventing phone numbers or hours).
 * - Attribution: Data © OpenStreetMap contributors, ODbL 1.0.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const OSM_SEARCH_URL = process.env.OSM_NOMINATIM_URL || 'https://nominatim.openstreetmap.org/search';
const USER_AGENT = 'NirbhayWomenSafetyApp/1.0 (contact: support@nirbhay.app)';

const SUPPORTED_CATEGORIES = {
  police: 'police',
  hospital: 'hospital',
  medical: 'hospital', // alias
  pharmacy: 'pharmacy',
  fire_station: 'fire_station',
  all: 'all',
};

// In-memory cache: `${latGrid}_${lngGrid}_${category}_${radiusGrid}` -> { timestamp, data }
const cache = new Map();
const CACHE_TTL_MS = 60 * 1000; // 60 seconds

// In-memory sliding window rate limiter: IP -> Array of timestamps
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 30; // 30 requests per minute per IP

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
 * Normalizes an OpenStreetMap Nominatim search element into a structured Place record.
 */
function normalizePlaceItem(item, userLat, userLng) {
  const itemLat = parseFloat(item.lat);
  const itemLng = parseFloat(item.lon);
  if (isNaN(itemLat) || isNaN(itemLng)) return null;

  const rawAmenity = (item.type || item.extratags?.amenity || '').toLowerCase();
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

  // Name: check item.name or first part of display_name, fallback to category name
  const name =
    item.name && item.name.trim().length > 0
      ? item.name.trim()
      : item.display_name
      ? item.display_name.split(',')[0].trim()
      : defaultName;

  // Full address
  let address = item.display_name || null;

  // Phone: check multiple common OSM / Nominatim tags across extratags, address, and tags
  const tags = { ...(item.tags || {}), ...(item.extratags || {}) };
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
    // Split on semicolon, slash, or comma if multiple numbers provided
    if (p.includes(';')) p = p.split(';')[0].trim();
    else if (p.includes('/')) p = p.split('/')[0].trim();
    else if (p.includes(',')) p = p.split(',')[0].trim();
    // Valid phone strings usually have at least 3 digits
    if ((p.match(/\d/g) || []).length >= 3) {
      phone = p;
    }
  }

  // Opening hours
  const openingHours = item.extratags?.opening_hours || null;
  let isOpen = null;
  if (openingHours) {
    const norm = openingHours.trim().toLowerCase();
    if (norm === '24/7' || norm === '24 hours' || norm === 'open 24/7') {
      isOpen = true;
    }
  }

  const distanceMeters = calculateDistanceMeters(userLat, userLng, itemLat, itemLng);

  return {
    id: `osm_${item.osm_type || 'node'}_${item.osm_id || item.place_id}`,
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
 * Checks in-memory rate limit for a client IP.
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
 * Fetch with timeout using native AbortController.
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
 * Queries OpenStreetMap for nearby safety places.
 *
 * @param {Object} params
 * @param {number} params.latitude
 * @param {number} params.longitude
 * @param {string} [params.category='all']
 * @param {number} [params.radius=5000] (in meters)
 * @param {number} [params.limit=20]
 * @param {string} [params.clientIp]
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

  // 3. Cache lookup (~100m grid rounding)
  const latGrid = Math.round(latNum * 100) / 100;
  const lngGrid = Math.round(lngNum * 100) / 100;
  const radiusGrid = Math.round(clampedRadius / 500) * 500;
  const cacheKey = `${latGrid}_${lngGrid}_${cleanCategory}_${radiusGrid}`;

  const cachedEntry = cache.get(cacheKey);
  if (cachedEntry && Date.now() - cachedEntry.timestamp < CACHE_TTL_MS) {
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
    };
  }

  // 4. Compute bounding box
  const viewbox = computeBoundingBox(latNum, lngNum, clampedRadius);

  // Categories to query
  const targetCategories =
    cleanCategory === 'all'
      ? ['police', 'hospital', 'pharmacy', 'fire_station']
      : [cleanCategory];

  // Request headers
  const requestHeaders = {
    'User-Agent': USER_AGENT,
    Accept: 'application/json',
  };

  // 5. Query OpenStreetMap
  const rawItems = [];
  try {
    const queryPromises = targetCategories.map(async (cat) => {
      const url = `${OSM_SEARCH_URL}?format=json&amenity=${encodeURIComponent(
        cat
      )}&bounded=1&viewbox=${viewbox}&limit=${clampedLimit}&addressdetails=1&extratags=1`;

      const res = await fetchWithTimeout(url, { headers: requestHeaders }, 8000);
      if (!res.ok) {
        if (res.status === 429) {
          const err = new Error('Places provider rate limit reached. Please retry in a few moments.');
          err.status = 429;
          err.code = 'PROVIDER_RATE_LIMIT';
          throw err;
        }
        return [];
      }
      const json = await res.json();
      return Array.isArray(json) ? json : [];
    });

    const categoryResults = await Promise.all(queryPromises);
    for (const list of categoryResults) {
      rawItems.push(...list);
    }
  } catch (err) {
    if (err.name === 'AbortError' || err.message?.includes('aborted')) {
      const timeoutErr = new Error('Nearby places provider timed out. Please try again.');
      timeoutErr.status = 504;
      timeoutErr.code = 'PROVIDER_TIMEOUT';
      throw timeoutErr;
    }
    if (err.status) throw err;

    const netErr = new Error('Unable to connect to nearby places data source.');
    netErr.status = 502;
    netErr.code = 'PROVIDER_UNAVAILABLE';
    throw netErr;
  }

  // 6. Normalize and deduplicate by place id
  const seenIds = new Set();
  const parsedPlaces = [];

  for (const item of rawItems) {
    const place = normalizePlaceItem(item, latNum, lngNum);
    if (!place) continue;
    if (seenIds.has(place.id)) continue;

    // Filter by actual circular radius
    if (place.distanceMeters <= clampedRadius) {
      seenIds.add(place.id);
      parsedPlaces.push(place);
    }
  }

  // Sort by closest distance first
  parsedPlaces.sort((a, b) => a.distanceMeters - b.distanceMeters);

  // Store in cache
  cache.set(cacheKey, {
    timestamp: Date.now(),
    places: parsedPlaces,
  });

  // Limit cache size
  if (cache.size > 200) {
    const firstKey = cache.keys().next().value;
    cache.delete(firstKey);
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
}

module.exports = {
  getNearbyPlaces,
  validateCoordinates,
  normalizeCategory,
  calculateDistanceMeters,
  formatDistance,
  computeBoundingBox,
  normalizePlaceItem,
  SUPPORTED_CATEGORIES,
};
