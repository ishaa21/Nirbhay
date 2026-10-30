/**
 * Hotspot Scoring and Clustering Service for Nirbhay
 *
 * Implements a transparent, reproducible scoring algorithm:
 * - Aggregates active, un-expired safety reports into geographic clusters.
 * - Deduplicates multiple reports from the same user to prevent spam/manipulation.
 * - Applies category weights and exponential recency decay.
 * - Enforces the rule that 1 single author/report can NEVER produce a RED zone.
 * - Supports route corridor proximity detection.
 */

const CATEGORY_WEIGHTS = {
  HARASSMENT: 1.25,
  UNSAFE_AREA: 1.15,
  SUSPICIOUS_ACTIVITY: 0.95,
  THEFT: 0.90,
  ROAD_SAFETY: 0.65,
  OTHER: 0.50,
  LOST_PERSON: 0.35,
  HELPFUL_INFO: 0.05,
};

// Earth radius in meters for geospatial calculations
const EARTH_RADIUS_METERS = 6371000;

/**
 * Calculates Haversine distance in meters between two lat/lng coordinates.
 */
function haversineDistanceMeters(lat1, lon1, lat2, lon2) {
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_METERS * c;
}

/**
 * Calculates recency decay factor based on days elapsed since report creation.
 * Exponential-like step decay. Reports older than 30 days have 0 weight.
 */
function getRecencyDecay(createdAt, referenceDate = new Date()) {
  const diffMs = referenceDate.getTime() - new Date(createdAt).getTime();
  const diffDays = Math.max(0, diffMs / (1000 * 60 * 60 * 24));

  if (diffDays <= 3) return 1.0;
  if (diffDays <= 7) return 0.8;
  if (diffDays <= 14) return 0.55;
  if (diffDays <= 30) return 0.25;
  return 0.0; // Expired
}

/**
 * Spatial clustering: groups points within clusterThresholdMeters (default 280m)
 */
function clusterReports(reports, clusterThresholdMeters = 280) {
  const clusters = [];
  const assigned = new Set();

  for (let i = 0; i < reports.length; i++) {
    if (assigned.has(reports[i].id)) continue;

    const currentCluster = [reports[i]];
    assigned.add(reports[i].id);

    for (let j = i + 1; j < reports.length; j++) {
      if (assigned.has(reports[j].id)) continue;

      const dist = haversineDistanceMeters(
        parseFloat(reports[i].latitude),
        parseFloat(reports[i].longitude),
        parseFloat(reports[j].latitude),
        parseFloat(reports[j].longitude)
      );

      if (dist <= clusterThresholdMeters) {
        currentCluster.push(reports[j]);
        assigned.add(reports[j].id);
      }
    }

    clusters.push(currentCluster);
  }

  return clusters;
}

/**
 * Computes risk score, risk level, centroid, and metadata for a cluster of reports.
 */
function computeHotspotDetails(cluster, referenceDate = new Date()) {
  if (!cluster || cluster.length === 0) return null;

  // Group by author to prevent manipulation from a single user
  const authorMap = new Map();
  const categoryCounts = {};
  let totalUpvotes = 0;
  let totalConfirmations = 0;
  let totalDisputes = 0;
  let latestReportAt = new Date(0);

  let sumLat = 0;
  let sumLng = 0;

  for (const report of cluster) {
    const lat = parseFloat(report.latitude);
    const lng = parseFloat(report.longitude);
    sumLat += lat;
    sumLng += lng;

    const cat = report.category || 'OTHER';
    categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;

    totalUpvotes += parseInt(report.upvotes_count || 0, 10);
    totalConfirmations += parseInt(report.confirmations_count || 0, 10);
    totalDisputes += parseInt(report.disputes_count || 0, 10);

    const reportDate = new Date(report.created_at);
    if (reportDate > latestReportAt) {
      latestReportAt = reportDate;
    }

    const userId = report.user_id || 'anonymous';
    if (!authorMap.has(userId)) {
      authorMap.set(userId, []);
    }
    authorMap.get(userId).push(report);
  }

  const centerLat = sumLat / cluster.length;
  const centerLng = sumLng / cluster.length;

  // Determine radius in meters to cover all cluster reports (min 150m, max 400m)
  let maxDistFromCenter = 0;
  for (const report of cluster) {
    const d = haversineDistanceMeters(
      centerLat,
      centerLng,
      parseFloat(report.latitude),
      parseFloat(report.longitude)
    );
    if (d > maxDistFromCenter) maxDistFromCenter = d;
  }
  const radiusMeters = Math.min(400, Math.max(150, Math.round(maxDistFromCenter + 50)));

  // Calculate author-deduplicated score
  let baseScore = 0;
  for (const [, userReports] of authorMap.entries()) {
    // Sort reports by severity * recency descending so primary report gets full weight
    userReports.sort((a, b) => {
      const wA = (CATEGORY_WEIGHTS[a.category] || 0.5) * getRecencyDecay(a.created_at, referenceDate);
      const wB = (CATEGORY_WEIGHTS[b.category] || 0.5) * getRecencyDecay(b.created_at, referenceDate);
      return wB - wA;
    });

    // First report from user gets 100% of its recency-weighted score
    const primary = userReports[0];
    const primaryWeight = CATEGORY_WEIGHTS[primary.category] || 0.5;
    const primaryDecay = getRecencyDecay(primary.created_at, referenceDate);
    baseScore += primaryWeight * primaryDecay;

    // Any subsequent reports from the same user are heavily discounted (15% max)
    for (let k = 1; k < userReports.length; k++) {
      const extra = userReports[k];
      const extraWeight = CATEGORY_WEIGHTS[extra.category] || 0.5;
      const extraDecay = getRecencyDecay(extra.created_at, referenceDate);
      baseScore += extraWeight * extraDecay * 0.15;
    }
  }

  // Community confirmation bonus (capped at +1.5)
  const confirmationBonus = Math.min(1.0, totalConfirmations * 0.25) + Math.min(0.5, totalUpvotes * 0.05);

  // Dispute penalty (-0.4 per dispute)
  const disputePenalty = totalDisputes * 0.4;

  const finalScore = Math.max(0, Math.round((baseScore + confirmationBonus - disputePenalty) * 10) / 10);
  const independentAuthorCount = authorMap.size;

  // Primary Category is the most frequent category (or highest weighted on tie)
  let primaryCategory = 'OTHER';
  let maxCount = -1;
  for (const [cat, count] of Object.entries(categoryCounts)) {
    if (count > maxCount || (count === maxCount && (CATEGORY_WEIGHTS[cat] || 0) > (CATEGORY_WEIGHTS[primaryCategory] || 0))) {
      maxCount = count;
      primaryCategory = cat;
    }
  }

  // Risk Level Determination:
  // RULE: Red zone MUST have score >= 4.0 AND at least 2 independent authors.
  let riskLevel = 'YELLOW';
  if (finalScore >= 4.0 && independentAuthorCount >= 2) {
    riskLevel = 'RED';
  } else if (finalScore >= 2.0 || (finalScore >= 1.5 && independentAuthorCount >= 2)) {
    riskLevel = 'ORANGE';
  } else if (finalScore >= 0.7) {
    riskLevel = 'YELLOW';
  } else {
    // Insignificant confidence
    return null;
  }

  // Verification Status
  let verificationStatus = 'COMMUNITY_REPORTED';
  if (totalDisputes >= 2 && totalDisputes >= totalConfirmations) {
    verificationStatus = 'DISPUTED';
  } else if (independentAuthorCount >= 2 || totalConfirmations >= 2 || totalUpvotes >= 5) {
    verificationStatus = 'COMMUNITY_VERIFIED';
  }

  // Deterministic ID based on center coordinates to 3 decimals
  const id = `hotspot_${Math.round(centerLat * 1000)}_${Math.round(centerLng * 1000)}`;

  // Human-readable summary
  const topReport = cluster[0];
  const locationName = topReport.location_name || `Area near ${centerLat.toFixed(3)}, ${centerLng.toFixed(3)}`;
  const summary = `${independentAuthorCount} community report${independentAuthorCount > 1 ? 's' : ''} regarding ${primaryCategory.toLowerCase().replace(/_/g, ' ')}.`;

  return {
    id,
    center: {
      latitude: Math.round(centerLat * 1000000) / 1000000,
      longitude: Math.round(centerLng * 1000000) / 1000000,
    },
    radiusMeters,
    riskScore: finalScore,
    riskLevel,
    primaryCategory,
    categoryCounts,
    reportCount: cluster.length,
    independentAuthorCount,
    latestReportAt: latestReportAt.toISOString(),
    verificationStatus,
    locationName,
    summary,
    confirmationsCount: totalConfirmations,
    disputesCount: totalDisputes,
    reports: cluster.map((r) => ({
      id: r.id,
      category: r.category,
      title: r.title,
      description: r.description,
      locationName: r.location_name,
      createdAt: r.created_at,
      upvotesCount: parseInt(r.upvotes_count || 0, 10),
      confirmationsCount: parseInt(r.confirmations_count || 0, 10),
      authorFullName: r.author_full_name || 'Nirbhay Member',
    })),
  };
}

/**
 * Evaluates whether a safety hotspot is along a user's route or trajectory.
 *
 * @param {Object} hotspot - The safety hotspot object with center.latitude, center.longitude
 * @param {Object} userLocation - { latitude, longitude, heading, speed }
 * @param {Array} routeWaypoints - Array of { latitude, longitude } representing upcoming path
 * @param {number} corridorWidthMeters - Maximum perpendicular distance from route corridor (default 350m)
 * @param {number} warningDistanceMeters - Lookahead distance threshold (default 600m)
 */
function evaluateRouteProximity(
  hotspot,
  userLocation,
  routeWaypoints = [],
  corridorWidthMeters = 350,
  warningDistanceMeters = 600
) {
  const directDistance = haversineDistanceMeters(
    userLocation.latitude,
    userLocation.longitude,
    hotspot.center.latitude,
    hotspot.center.longitude
  );

  // If outside overall search distance, skip
  if (directDistance > warningDistanceMeters + hotspot.radiusMeters) {
    return { isApproaching: false, distanceMeters: directDistance, isAlongRoute: false };
  }

  // Inside hotspot radius
  if (directDistance <= hotspot.radiusMeters) {
    return {
      isApproaching: true,
      distanceMeters: Math.round(directDistance),
      isAlongRoute: true,
      tier: 'INSIDE',
    };
  }

  // If route waypoints provided, check if hotspot is within corridor of any upcoming route segment
  let minDistanceToRoute = directDistance;
  let isAlongRoute = false;

  if (routeWaypoints && routeWaypoints.length >= 2) {
    for (let i = 0; i < routeWaypoints.length - 1; i++) {
      const p1 = routeWaypoints[i];
      const p2 = routeWaypoints[i + 1];

      const crossTrack = pointToSegmentDistanceMeters(
        hotspot.center.latitude,
        hotspot.center.longitude,
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude
      );

      if (crossTrack < minDistanceToRoute) {
        minDistanceToRoute = crossTrack;
      }

      if (crossTrack <= corridorWidthMeters + hotspot.radiusMeters) {
        isAlongRoute = true;
      }
    }
  } else {
    // If no multi-point route waypoints, use heading/trajectory if available
    isAlongRoute = directDistance <= corridorWidthMeters + hotspot.radiusMeters;
  }

  // Determine warning tier
  let tier = 'NONE';
  const effectiveDistance = Math.max(0, directDistance - hotspot.radiusMeters);

  if (effectiveDistance <= 80) {
    tier = 'INSIDE';
  } else if (effectiveDistance <= 250) {
    tier = 'APPROACHING';
  } else if (effectiveDistance <= warningDistanceMeters) {
    tier = 'EARLY';
  }

  return {
    isApproaching: isAlongRoute && tier !== 'NONE',
    distanceMeters: Math.round(directDistance),
    effectiveDistanceMeters: Math.round(effectiveDistance),
    isAlongRoute,
    tier,
  };
}

/**
 * Calculates perpendicular distance from a point to a line segment in meters.
 */
function pointToSegmentDistanceMeters(pLat, pLon, aLat, aLon, bLat, bLon) {
  // Convert spherical coords to local planar approximation in meters
  const dLatA = ((pLat - aLat) * Math.PI) / 180 * EARTH_RADIUS_METERS;
  const dLonA = ((pLon - aLon) * Math.PI) / 180 * EARTH_RADIUS_METERS * Math.cos((aLat * Math.PI) / 180);

  const dLatB = ((bLat - aLat) * Math.PI) / 180 * EARTH_RADIUS_METERS;
  const dLonB = ((bLon - aLon) * Math.PI) / 180 * EARTH_RADIUS_METERS * Math.cos((aLat * Math.PI) / 180);

  const l2 = dLatB * dLatB + dLonB * dLonB;
  if (l2 === 0) return Math.sqrt(dLatA * dLatA + dLonA * dLonA);

  const t = Math.max(0, Math.min(1, (dLatA * dLatB + dLonA * dLonB) / l2));
  const projLat = dLatA - t * dLatB;
  const projLon = dLonA - t * dLonB;

  return Math.sqrt(projLat * projLat + projLon * projLon);
}

module.exports = {
  CATEGORY_WEIGHTS,
  haversineDistanceMeters,
  getRecencyDecay,
  clusterReports,
  computeHotspotDetails,
  evaluateRouteProximity,
};
