const db = require('../config/db');
const {
  clusterReports,
  computeHotspotDetails,
  evaluateRouteProximity,
  haversineDistanceMeters,
} = require('../services/hotspotScoringService');

// Allowed categories
const ALLOWED_CATEGORIES = [
  'SUSPICIOUS_ACTIVITY',
  'HARASSMENT',
  'UNSAFE_AREA',
  'THEFT',
  'ROAD_SAFETY',
  'LOST_PERSON',
  'HELPFUL_INFO',
  'OTHER',
];

// Allowed report reasons
const ALLOWED_REPORT_REASONS = [
  'INACCURATE',
  'ABUSIVE',
  'SPAM',
  'DANGEROUS',
  'DOXXING',
  'OTHER',
];

// UUID validation regex
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const isValidUuid = (id) => typeof id === 'string' && UUID_REGEX.test(id);

/**
 * Coarsen coordinates to 3 decimal places (~110m precision)
 * to protect exact private residences and pinpoint locations.
 */
const coarsenCoordinate = (val) => {
  if (val === undefined || val === null || val === '') return null;
  const num = parseFloat(val);
  if (isNaN(num)) return null;
  return Math.round(num * 1000) / 1000;
};

/**
 * Mask author name for public safety / privacy: e.g. "Priya Sharma" -> "Priya S."
 */
const maskAuthorName = (fullName) => {
  if (!fullName || typeof fullName !== 'string') return 'Nirbhay Member';
  const parts = fullName.trim().split(/\s+/);
  if (parts.length === 1) return parts[0];
  const first = parts[0];
  const lastInitial = parts[parts.length - 1][0].toUpperCase();
  return `${first} ${lastInitial}.`;
};

/**
 * GET /api/community/posts
 * Paginated feed with category, sort, and nearby filters.
 */
const getPosts = async (req, res) => {
  try {
    const userId = req.userId || null;
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 15));
    const offset = (page - 1) * limit;

    const { category, sort, latitude, longitude } = req.query;
    const radiusKm = Math.min(100, Math.max(1, parseFloat(req.query.radiusKm) || 10));

    const conditions = ["p.status = 'ACTIVE'", "p.moderation_status != 'BLOCKED'"];
    // Hide posts that have been flagged by 3+ reports
    conditions.push("NOT (p.moderation_status = 'FLAGGED' AND p.reports_count >= 3)");
    const params = [];

    // Category filter
    if (category && category !== 'ALL') {
      const upperCat = category.toUpperCase();
      if (ALLOWED_CATEGORIES.includes(upperCat)) {
        params.push(upperCat);
        conditions.push(`p.category = $${params.length}`);
      }
    }

    let orderBy = 'p.created_at DESC';
    let distanceSelect = 'NULL::numeric AS distance_km';

    // Nearby sort
    const hasCoordinates =
      latitude !== undefined &&
      longitude !== undefined &&
      !isNaN(parseFloat(latitude)) &&
      !isNaN(parseFloat(longitude));

    if (sort === 'nearby' && hasCoordinates) {
      const lat = parseFloat(latitude);
      const lng = parseFloat(longitude);
      params.push(lat, lng, radiusKm);
      const latIdx = params.length - 2;
      const lngIdx = params.length - 1;
      const radIdx = params.length;

      // Haversine formula
      const haversine = `(6371 * acos(
        LEAST(1.0, GREATEST(-1.0,
          cos(radians($${latIdx})) * cos(radians(p.latitude)) *
          cos(radians(p.longitude) - radians($${lngIdx})) +
          sin(radians($${latIdx})) * sin(radians(p.latitude))
        ))
      ))`;

      conditions.push('p.latitude IS NOT NULL AND p.longitude IS NOT NULL');
      conditions.push(`${haversine} <= $${radIdx}`);
      distanceSelect = `ROUND(${haversine}::numeric, 2) AS distance_km`;
      orderBy = `${haversine} ASC, p.created_at DESC`;
    } else if (sort === 'most_upvoted') {
      orderBy = 'p.upvotes_count DESC, p.created_at DESC';
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Total count for pagination
    const countSql = `SELECT COUNT(*) AS total FROM community_posts p ${whereClause}`;
    const countResult = await db.query(countSql, params);
    const total = parseInt(countResult.rows[0].total, 10) || 0;
    const totalPages = Math.ceil(total / limit) || 1;

    // Fetch posts
    params.push(limit, offset);
    const limitIdx = params.length - 1;
    const offsetIdx = params.length;

    // Subquery or join for upvoted status
    let upvotedSelect = 'false AS has_upvoted';
    let isOwnerSelect = 'false AS is_owner';
    if (userId) {
      params.push(userId);
      const userParamIdx = params.length;
      upvotedSelect = `EXISTS(SELECT 1 FROM community_upvotes WHERE post_id = p.id AND user_id = $${userParamIdx}) AS has_upvoted`;
      isOwnerSelect = `(p.user_id = $${userParamIdx}) AS is_owner`;
    }

    const postsSql = `
      SELECT p.id, p.user_id, p.category, p.title, p.description,
             p.location_name, p.latitude, p.longitude,
             p.status, p.moderation_status,
             p.upvotes_count, p.comments_count, p.reports_count,
             p.created_at, p.updated_at,
             u.full_name AS author_full_name,
             ${distanceSelect},
             ${upvotedSelect},
             ${isOwnerSelect}
      FROM community_posts p
      JOIN users u ON u.id = p.user_id
      ${whereClause}
      ORDER BY ${orderBy}
      LIMIT $${limitIdx} OFFSET $${offsetIdx}
    `;

    const result = await db.query(postsSql, params);

    const posts = result.rows.map((row) => ({
      id: row.id,
      category: row.category,
      title: row.title,
      description: row.description,
      locationName: row.location_name,
      latitude: row.latitude ? parseFloat(row.latitude) : null,
      longitude: row.longitude ? parseFloat(row.longitude) : null,
      upvotesCount: row.upvotes_count,
      commentsCount: row.comments_count,
      authorName: maskAuthorName(row.author_full_name),
      authorId: row.user_id,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      distanceKm: row.distance_km ? parseFloat(row.distance_km) : null,
      hasUpvoted: Boolean(row.has_upvoted),
      isOwner: Boolean(row.is_owner),
    }));

    return res.status(200).json({
      success: true,
      posts,
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasMore: page < totalPages,
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error fetching posts:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch community posts.',
      error: error.message,
    });
  }
};

/**
 * GET /api/community/posts/:id
 * Fetch single post with author and top comments.
 */
const getPostById = async (req, res) => {
  const { id } = req.params;
  const userId = req.userId || null;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  try {
    let upvotedSelect = 'false AS has_upvoted';
    let isOwnerSelect = 'false AS is_owner';
    const params = [id];

    if (userId) {
      params.push(userId);
      upvotedSelect = `EXISTS(SELECT 1 FROM community_upvotes WHERE post_id = p.id AND user_id = $2) AS has_upvoted`;
      isOwnerSelect = `(p.user_id = $2) AS is_owner`;
    }

    const postResult = await db.query(
      `SELECT p.id, p.user_id, p.category, p.title, p.description,
              p.location_name, p.latitude, p.longitude,
              p.status, p.moderation_status,
              p.upvotes_count, p.comments_count, p.reports_count,
              p.created_at, p.updated_at,
              u.full_name AS author_full_name,
              ${upvotedSelect},
              ${isOwnerSelect}
       FROM community_posts p
       JOIN users u ON u.id = p.user_id
       WHERE p.id = $1 AND p.status != 'DELETED' AND p.moderation_status != 'BLOCKED'`,
      params
    );

    if (postResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Community post not found.' });
    }

    const row = postResult.rows[0];

    // Fetch initial comments (first 20)
    const commentsParams = [id];
    let commentOwnerSelect = 'false AS is_owner';
    if (userId) {
      commentsParams.push(userId);
      commentOwnerSelect = `(c.user_id = $2) AS is_owner`;
    }

    const commentsResult = await db.query(
      `SELECT c.id, c.content, c.created_at, c.user_id,
              u.full_name AS author_full_name,
              ${commentOwnerSelect}
       FROM community_comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.post_id = $1 AND c.status = 'ACTIVE'
       ORDER BY c.created_at ASC
       LIMIT 50`,
      commentsParams
    );

    const comments = commentsResult.rows.map((c) => ({
      id: c.id,
      content: c.content,
      authorName: maskAuthorName(c.author_full_name),
      authorId: c.user_id,
      createdAt: c.created_at,
      isOwner: Boolean(c.is_owner),
    }));

    return res.status(200).json({
      success: true,
      post: {
        id: row.id,
        category: row.category,
        title: row.title,
        description: row.description,
        locationName: row.location_name,
        latitude: row.latitude ? parseFloat(row.latitude) : null,
        longitude: row.longitude ? parseFloat(row.longitude) : null,
        upvotesCount: row.upvotes_count,
        commentsCount: row.comments_count,
        authorName: maskAuthorName(row.author_full_name),
        authorId: row.user_id,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        hasUpvoted: Boolean(row.has_upvoted),
        isOwner: Boolean(row.is_owner),
        comments,
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error fetching post by id:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch community post.',
      error: error.message,
    });
  }
};

/**
 * POST /api/community/posts
 * Create a new safety report or community post.
 */
const createPost = async (req, res) => {
  const userId = req.userId;
  const { title, description, category, location_name, latitude, longitude } = req.body;

  // Validation
  if (!title || typeof title !== 'string' || title.trim().length < 3) {
    return res.status(400).json({
      success: false,
      message: 'Title is required and must be at least 3 characters long.',
    });
  }
  if (title.trim().length > 200) {
    return res.status(400).json({
      success: false,
      message: 'Title cannot exceed 200 characters.',
    });
  }

  if (!description || typeof description !== 'string' || description.trim().length < 10) {
    return res.status(400).json({
      success: false,
      message: 'Description is required and must be at least 10 characters long.',
    });
  }
  if (description.trim().length > 3000) {
    return res.status(400).json({
      success: false,
      message: 'Description cannot exceed 3000 characters.',
    });
  }

  const cleanCategory = (category || 'OTHER').toUpperCase().trim();
  if (!ALLOWED_CATEGORIES.includes(cleanCategory)) {
    return res.status(400).json({
      success: false,
      message: `Invalid category. Must be one of: ${ALLOWED_CATEGORIES.join(', ')}.`,
    });
  }

  // Location validation & privacy coarsening
  const coarseLat = coarsenCoordinate(latitude);
  const coarseLng = coarsenCoordinate(longitude);

  if (coarseLat !== null && (coarseLat < -90 || coarseLat > 90)) {
    return res.status(400).json({ success: false, message: 'Latitude out of range [-90, 90].' });
  }
  if (coarseLng !== null && (coarseLng < -180 || coarseLng > 180)) {
    return res.status(400).json({ success: false, message: 'Longitude out of range [-180, 180].' });
  }

  const cleanLocationName = location_name && typeof location_name === 'string'
    ? location_name.trim().slice(0, 255)
    : null;

  try {
    const insertResult = await db.query(
      `INSERT INTO community_posts
         (user_id, category, title, description, location_name, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        userId,
        cleanCategory,
        title.trim(),
        description.trim(),
        cleanLocationName,
        coarseLat,
        coarseLng,
      ]
    );

    const post = insertResult.rows[0];

    // Fetch user's name
    const userRes = await db.query('SELECT full_name FROM users WHERE id = $1', [userId]);
    const authorName = userRes.rows.length > 0 ? maskAuthorName(userRes.rows[0].full_name) : 'You';

    return res.status(201).json({
      success: true,
      message: 'Safety report posted successfully.',
      post: {
        id: post.id,
        category: post.category,
        title: post.title,
        description: post.description,
        locationName: post.location_name,
        latitude: post.latitude ? parseFloat(post.latitude) : null,
        longitude: post.longitude ? parseFloat(post.longitude) : null,
        upvotesCount: 0,
        commentsCount: 0,
        authorName,
        authorId: post.user_id,
        createdAt: post.created_at,
        updatedAt: post.updated_at,
        hasUpvoted: false,
        isOwner: true,
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error creating post:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to create community post.',
      error: error.message,
    });
  }
};

/**
 * PATCH /api/community/posts/:id
 * Edit author's own post.
 */
const updatePost = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { title, description, category } = req.body;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  try {
    const existing = await db.query(
      'SELECT id, user_id, status FROM community_posts WHERE id = $1',
      [id]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found.' });
    }

    const post = existing.rows[0];
    if (post.user_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to edit this post.',
      });
    }

    if (post.status === 'DELETED') {
      return res.status(400).json({ success: false, message: 'Cannot edit a deleted post.' });
    }

    const updates = [];
    const params = [id];

    if (title !== undefined) {
      if (typeof title !== 'string' || title.trim().length < 3 || title.trim().length > 200) {
        return res.status(400).json({
          success: false,
          message: 'Title must be between 3 and 200 characters.',
        });
      }
      params.push(title.trim());
      updates.push(`title = $${params.length}`);
    }

    if (description !== undefined) {
      if (typeof description !== 'string' || description.trim().length < 10 || description.trim().length > 3000) {
        return res.status(400).json({
          success: false,
          message: 'Description must be between 10 and 3000 characters.',
        });
      }
      params.push(description.trim());
      updates.push(`description = $${params.length}`);
    }

    if (category !== undefined) {
      const cleanCat = category.toUpperCase().trim();
      if (!ALLOWED_CATEGORIES.includes(cleanCat)) {
        return res.status(400).json({
          success: false,
          message: `Invalid category. Must be one of: ${ALLOWED_CATEGORIES.join(', ')}.`,
        });
      }
      params.push(cleanCat);
      updates.push(`category = $${params.length}`);
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'No valid fields provided to update.' });
    }

    updates.push('updated_at = NOW()');

    const updateSql = `
      UPDATE community_posts
      SET ${updates.join(', ')}
      WHERE id = $1
      RETURNING *
    `;

    const updated = await db.query(updateSql, params);
    const updatedPost = updated.rows[0];

    return res.status(200).json({
      success: true,
      message: 'Post updated successfully.',
      post: {
        id: updatedPost.id,
        category: updatedPost.category,
        title: updatedPost.title,
        description: updatedPost.description,
        locationName: updatedPost.location_name,
        latitude: updatedPost.latitude ? parseFloat(updatedPost.latitude) : null,
        longitude: updatedPost.longitude ? parseFloat(updatedPost.longitude) : null,
        upvotesCount: updatedPost.upvotes_count,
        commentsCount: updatedPost.comments_count,
        createdAt: updatedPost.created_at,
        updatedAt: updatedPost.updated_at,
        isOwner: true,
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error updating post:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update post.',
      error: error.message,
    });
  }
};

/**
 * DELETE /api/community/posts/:id
 * Soft delete author's own post.
 */
const deletePost = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  try {
    const existing = await db.query(
      'SELECT id, user_id, status FROM community_posts WHERE id = $1',
      [id]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found.' });
    }

    const post = existing.rows[0];
    if (post.user_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to delete this post.',
      });
    }

    await db.query(
      "UPDATE community_posts SET status = 'DELETED', updated_at = NOW() WHERE id = $1",
      [id]
    );

    return res.status(200).json({
      success: true,
      message: 'Post deleted successfully.',
    });
  } catch (error) {
    console.error('[COMMUNITY] Error deleting post:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete post.',
      error: error.message,
    });
  }
};

/**
 * POST /api/community/posts/:id/upvote
 * Upvote a post. Toggles off if already upvoted or adds if not upvoted.
 */
const upvotePost = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  try {
    // Check if post exists and is active
    const postRes = await db.query(
      "SELECT id, status, upvotes_count FROM community_posts WHERE id = $1 AND status = 'ACTIVE'",
      [id]
    );
    if (postRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Active post not found.' });
    }

    // Check if already upvoted
    const existingUpvote = await db.query(
      'SELECT id FROM community_upvotes WHERE post_id = $1 AND user_id = $2',
      [id, userId]
    );

    if (existingUpvote.rows.length > 0) {
      // Toggle off / remove upvote
      await db.query('DELETE FROM community_upvotes WHERE post_id = $1 AND user_id = $2', [id, userId]);
      const updated = await db.query(
        'UPDATE community_posts SET upvotes_count = GREATEST(0, upvotes_count - 1) WHERE id = $1 RETURNING upvotes_count',
        [id]
      );
      return res.status(200).json({
        success: true,
        upvoted: false,
        upvotesCount: updated.rows[0].upvotes_count,
        message: 'Upvote removed.',
      });
    } else {
      // Add upvote
      await db.query(
        'INSERT INTO community_upvotes (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [id, userId]
      );
      const updated = await db.query(
        'UPDATE community_posts SET upvotes_count = upvotes_count + 1 WHERE id = $1 RETURNING upvotes_count',
        [id]
      );
      return res.status(200).json({
        success: true,
        upvoted: true,
        upvotesCount: updated.rows[0].upvotes_count,
        message: 'Post upvoted.',
      });
    }
  } catch (error) {
    console.error('[COMMUNITY] Error upvoting post:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update upvote.',
      error: error.message,
    });
  }
};

/**
 * DELETE /api/community/posts/:id/upvote
 * Explicitly remove upvote.
 */
const removeUpvote = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  try {
    const deleted = await db.query(
      'DELETE FROM community_upvotes WHERE post_id = $1 AND user_id = $2 RETURNING id',
      [id, userId]
    );

    if (deleted.rows.length > 0) {
      const updated = await db.query(
        'UPDATE community_posts SET upvotes_count = GREATEST(0, upvotes_count - 1) WHERE id = $1 RETURNING upvotes_count',
        [id]
      );
      return res.status(200).json({
        success: true,
        upvoted: false,
        upvotesCount: updated.rows[0].upvotes_count,
        message: 'Upvote removed.',
      });
    }

    const current = await db.query('SELECT upvotes_count FROM community_posts WHERE id = $1', [id]);
    return res.status(200).json({
      success: true,
      upvoted: false,
      upvotesCount: current.rows[0]?.upvotes_count || 0,
      message: 'Post was not upvoted.',
    });
  } catch (error) {
    console.error('[COMMUNITY] Error removing upvote:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to remove upvote.',
      error: error.message,
    });
  }
};

/**
 * GET /api/community/posts/:id/comments
 * Fetch paginated comments for a post.
 */
const getComments = async (req, res) => {
  const { id } = req.params;
  const userId = req.userId || null;
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 50));
  const offset = (page - 1) * limit;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  try {
    const countRes = await db.query(
      "SELECT COUNT(*) AS total FROM community_comments WHERE post_id = $1 AND status = 'ACTIVE'",
      [id]
    );
    const total = parseInt(countRes.rows[0].total, 10) || 0;

    const params = [id, limit, offset];
    let isOwnerSelect = 'false AS is_owner';
    if (userId) {
      params.push(userId);
      isOwnerSelect = `(c.user_id = $4) AS is_owner`;
    }

    const commentsRes = await db.query(
      `SELECT c.id, c.content, c.created_at, c.user_id,
              u.full_name AS author_full_name,
              ${isOwnerSelect}
       FROM community_comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.post_id = $1 AND c.status = 'ACTIVE'
       ORDER BY c.created_at ASC
       LIMIT $2 OFFSET $3`,
      params
    );

    const comments = commentsRes.rows.map((c) => ({
      id: c.id,
      content: c.content,
      authorName: maskAuthorName(c.author_full_name),
      authorId: c.user_id,
      createdAt: c.created_at,
      isOwner: Boolean(c.is_owner),
    }));

    return res.status(200).json({
      success: true,
      comments,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error fetching comments:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch comments.',
      error: error.message,
    });
  }
};

/**
 * POST /api/community/posts/:id/comments
 * Add a comment to a post.
 */
const addComment = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { content } = req.body;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  if (!content || typeof content !== 'string' || content.trim().length === 0) {
    return res.status(400).json({
      success: false,
      message: 'Comment content cannot be empty.',
    });
  }

  if (content.trim().length > 1000) {
    return res.status(400).json({
      success: false,
      message: 'Comment cannot exceed 1000 characters.',
    });
  }

  try {
    // Check if post exists and is active
    const postRes = await db.query(
      "SELECT id, status FROM community_posts WHERE id = $1 AND status = 'ACTIVE'",
      [id]
    );
    if (postRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Active post not found.' });
    }

    const insertRes = await db.query(
      `INSERT INTO community_comments (post_id, user_id, content)
       VALUES ($1, $2, $3)
       RETURNING id, content, created_at, user_id`,
      [id, userId, content.trim()]
    );

    // Increment comments_count on post
    await db.query(
      'UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = $1',
      [id]
    );

    const userRes = await db.query('SELECT full_name FROM users WHERE id = $1', [userId]);
    const authorName = userRes.rows.length > 0 ? maskAuthorName(userRes.rows[0].full_name) : 'You';
    const comment = insertRes.rows[0];

    return res.status(201).json({
      success: true,
      message: 'Comment added successfully.',
      comment: {
        id: comment.id,
        content: comment.content,
        authorName,
        authorId: comment.user_id,
        createdAt: comment.created_at,
        isOwner: true,
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error adding comment:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to add comment.',
      error: error.message,
    });
  }
};

/**
 * DELETE /api/community/posts/:id/comments/:commentId
 * Author deletes their comment.
 */
const deleteComment = async (req, res) => {
  const userId = req.userId;
  const { id, commentId } = req.params;

  if (!isValidUuid(id) || !isValidUuid(commentId)) {
    return res.status(400).json({ success: false, message: 'Invalid ID format.' });
  }

  try {
    const existing = await db.query(
      'SELECT id, user_id, status FROM community_comments WHERE id = $1 AND post_id = $2',
      [commentId, id]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Comment not found.' });
    }

    if (existing.rows[0].user_id !== userId) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to delete this comment.',
      });
    }

    await db.query(
      "UPDATE community_comments SET status = 'DELETED', updated_at = NOW() WHERE id = $1",
      [commentId]
    );

    await db.query(
      'UPDATE community_posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = $1',
      [id]
    );

    return res.status(200).json({
      success: true,
      message: 'Comment deleted successfully.',
    });
  } catch (error) {
    console.error('[COMMUNITY] Error deleting comment:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete comment.',
      error: error.message,
    });
  }
};

/**
 * POST /api/community/posts/:id/report
 * Flag/report inappropriate, abusive, or dangerous content.
 */
const reportPost = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { reason, details } = req.body;

  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid post ID format.' });
  }

  const cleanReason = (reason || '').toUpperCase().trim();
  if (!ALLOWED_REPORT_REASONS.includes(cleanReason)) {
    return res.status(400).json({
      success: false,
      message: `Invalid report reason. Must be one of: ${ALLOWED_REPORT_REASONS.join(', ')}.`,
    });
  }

  const cleanDetails = details && typeof details === 'string'
    ? details.trim().slice(0, 500)
    : null;

  try {
    const postRes = await db.query('SELECT id, reports_count FROM community_posts WHERE id = $1', [id]);
    if (postRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found.' });
    }

    // Insert report (deduplicated per user per post)
    const reportInsert = await db.query(
      `INSERT INTO community_reports (post_id, user_id, reason, details)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (post_id, user_id) DO NOTHING
       RETURNING id`,
      [id, userId, cleanReason, cleanDetails]
    );

    if (reportInsert.rows.length > 0) {
      // Increment reports count
      const updatedPost = await db.query(
        'UPDATE community_posts SET reports_count = reports_count + 1 WHERE id = $1 RETURNING reports_count',
        [id]
      );
      const newCount = updatedPost.rows[0].reports_count;

      // Auto-moderation check: if 3 or more reports or DOXXING/DANGEROUS, flag post
      if (newCount >= 3 || cleanReason === 'DOXXING' || cleanReason === 'DANGEROUS') {
        await db.query(
          "UPDATE community_posts SET moderation_status = 'FLAGGED' WHERE id = $1",
          [id]
        );
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Thank you for reporting. Our moderation team will review this content.',
    });
  } catch (error) {
    console.error('[COMMUNITY] Error reporting post:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to submit report.',
      error: error.message,
    });
  }
};

/**
 * GET /api/community/my-posts
 * List authenticated user's own reports/posts.
 */
const getMyPosts = async (req, res) => {
  const userId = req.userId;
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  try {
    const countRes = await db.query(
      "SELECT COUNT(*) AS total FROM community_posts WHERE user_id = $1 AND status != 'DELETED'",
      [userId]
    );
    const total = parseInt(countRes.rows[0].total, 10) || 0;

    const postsRes = await db.query(
      `SELECT p.id, p.category, p.title, p.description,
              p.location_name, p.latitude, p.longitude,
              p.status, p.moderation_status,
              p.upvotes_count, p.comments_count, p.reports_count,
              p.created_at, p.updated_at,
              u.full_name AS author_full_name,
              EXISTS(SELECT 1 FROM community_upvotes WHERE post_id = p.id AND user_id = $1) AS has_upvoted
       FROM community_posts p
       JOIN users u ON u.id = p.user_id
       WHERE p.user_id = $1 AND p.status != 'DELETED'
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );

    const posts = postsRes.rows.map((row) => ({
      id: row.id,
      category: row.category,
      title: row.title,
      description: row.description,
      locationName: row.location_name,
      latitude: row.latitude ? parseFloat(row.latitude) : null,
      longitude: row.longitude ? parseFloat(row.longitude) : null,
      status: row.status,
      moderationStatus: row.moderation_status,
      upvotesCount: row.upvotes_count,
      commentsCount: row.comments_count,
      authorName: maskAuthorName(row.author_full_name),
      authorId: userId,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      hasUpvoted: Boolean(row.has_upvoted),
      isOwner: true,
    }));

    return res.status(200).json({
      success: true,
      posts,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
        hasMore: page < Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('[COMMUNITY] Error fetching my posts:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch your posts.',
      error: error.message,
    });
  }
};

/**
 * Helper to fetch active qualifying safety posts for hotspot calculation.
 */
const fetchActiveSafetyReports = async ({
  minLat,
  minLng,
  maxLat,
  maxLng,
  latitude,
  longitude,
  radiusKm,
  category,
} = {}) => {
  const conditions = [
    "p.status = 'ACTIVE'",
    "p.moderation_status != 'BLOCKED'",
    "p.resolution_status != 'RESOLVED'",
    "NOT (p.moderation_status = 'FLAGGED' AND p.reports_count >= 3)",
    "p.latitude IS NOT NULL",
    "p.longitude IS NOT NULL",
    "p.created_at >= NOW() - INTERVAL '30 days'",
  ];
  const params = [];

  // Bounding box filter
  if (
    minLat !== undefined &&
    minLng !== undefined &&
    maxLat !== undefined &&
    maxLng !== undefined
  ) {
    params.push(parseFloat(minLat), parseFloat(maxLat), parseFloat(minLng), parseFloat(maxLng));
    conditions.push(
      `p.latitude >= $${params.length - 3} AND p.latitude <= $${params.length - 2}`
    );
    conditions.push(
      `p.longitude >= $${params.length - 1} AND p.longitude <= $${params.length}`
    );
  } else if (
    latitude !== undefined &&
    longitude !== undefined &&
    !isNaN(parseFloat(latitude)) &&
    !isNaN(parseFloat(longitude))
  ) {
    const rKm = Math.min(100, Math.max(0.5, parseFloat(radiusKm) || 10));
    params.push(parseFloat(latitude), parseFloat(longitude), rKm);
    const latIdx = params.length - 2;
    const lngIdx = params.length - 1;
    const radIdx = params.length;

    const haversine = `(6371 * acos(
      LEAST(1.0, GREATEST(-1.0,
        cos(radians($${latIdx})) * cos(radians(p.latitude)) *
        cos(radians(p.longitude) - radians($${lngIdx})) +
        sin(radians($${latIdx})) * sin(radians(p.latitude))
      ))
    ))`;
    conditions.push(`${haversine} <= $${radIdx}`);
  }

  // Category filter
  if (category && category !== 'ALL') {
    const upperCat = category.toUpperCase();
    if (ALLOWED_CATEGORIES.includes(upperCat)) {
      params.push(upperCat);
      conditions.push(`p.category = $${params.length}`);
    }
  }

  const sql = `
    SELECT p.id, p.user_id, p.category, p.title, p.description,
           p.location_name, p.latitude, p.longitude,
           p.status, p.moderation_status, p.resolution_status,
           p.upvotes_count, p.comments_count, p.reports_count,
           p.confirmations_count, p.disputes_count,
           p.created_at, p.updated_at,
           u.full_name AS author_full_name
    FROM community_posts p
    JOIN users u ON u.id = p.user_id
    WHERE ${conditions.join(' AND ')}
    ORDER BY p.created_at DESC
    LIMIT 200
  `;

  const result = await db.query(sql, params);
  return result.rows.map((row) => ({
    id: row.id,
    user_id: row.user_id,
    category: row.category,
    title: row.title,
    description: row.description,
    location_name: row.location_name,
    latitude: parseFloat(row.latitude),
    longitude: parseFloat(row.longitude),
    upvotes_count: row.upvotes_count,
    confirmations_count: row.confirmations_count,
    disputes_count: row.disputes_count,
    created_at: row.created_at,
    author_full_name: maskAuthorName(row.author_full_name),
  }));
};

/**
 * GET /api/community/safety-hotspots
 * Query active safety hotspots with bounding box or radius filters.
 */
const getSafetyHotspots = async (req, res) => {
  try {
    const { minLat, minLng, maxLat, maxLng, latitude, longitude, radiusKm, category } = req.query;

    const reports = await fetchActiveSafetyReports({
      minLat,
      minLng,
      maxLat,
      maxLng,
      latitude,
      longitude,
      radiusKm,
      category,
    });

    const clusters = clusterReports(reports);
    const hotspots = [];

    for (const cluster of clusters) {
      const details = computeHotspotDetails(cluster);
      if (details) {
        hotspots.push(details);
      }
    }

    // Sort by risk score descending
    hotspots.sort((a, b) => b.riskScore - a.riskScore);

    return res.status(200).json({
      success: true,
      hotspots,
      count: hotspots.length,
      disclaimer:
        'Safety information is based on community reports. Reports may be incomplete or outdated and do not establish that an area is definitely unsafe. Please use your judgment.',
    });
  } catch (error) {
    console.error('[HOTSPOTS] Error calculating safety hotspots:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to calculate community safety hotspots.',
      error: error.message,
    });
  }
};

/**
 * GET /api/community/safety-hotspots/nearby
 * Returns nearby safety hotspots within radius in meters (default 5000m).
 */
const getNearbyHotspots = async (req, res) => {
  try {
    const { latitude, longitude, radiusMeters, category } = req.query;
    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        message: 'latitude and longitude query parameters are required.',
      });
    }

    const radiusKm = Math.min(50, Math.max(0.1, (parseFloat(radiusMeters) || 5000) / 1000));
    const reports = await fetchActiveSafetyReports({
      latitude,
      longitude,
      radiusKm,
      category,
    });

    const clusters = clusterReports(reports);
    const hotspots = [];

    for (const cluster of clusters) {
      const details = computeHotspotDetails(cluster);
      if (details) {
        hotspots.push(details);
      }
    }

    // Sort by proximity to user
    const userLat = parseFloat(latitude);
    const userLng = parseFloat(longitude);
    hotspots.sort((a, b) => {
      const distA = haversineDistanceMeters(userLat, userLng, a.center.latitude, a.center.longitude);
      const distB = haversineDistanceMeters(userLat, userLng, b.center.latitude, b.center.longitude);
      return distA - distB;
    });

    return res.status(200).json({
      success: true,
      hotspots,
      count: hotspots.length,
      disclaimer:
        'Safety information is based on community reports. Reports may be incomplete or outdated and do not establish that an area is definitely unsafe. Please use your judgment.',
    });
  } catch (error) {
    console.error('[HOTSPOTS] Error fetching nearby hotspots:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve nearby safety hotspots.',
      error: error.message,
    });
  }
};

/**
 * GET /api/community/safety-hotspots/:id
 * Fetch detailed information for a specific hotspot by its generated ID.
 */
const getHotspotById = async (req, res) => {
  try {
    const { id } = req.params;

    // Hotspot IDs are formatted as "hotspot_LATx1000_LNGx1000"
    const match = id.match(/^hotspot_(-?\d+)_(-?\d+)$/);
    if (!match) {
      return res.status(404).json({
        success: false,
        message: 'Invalid hotspot identifier format.',
      });
    }

    const approxLat = parseInt(match[1], 10) / 1000;
    const approxLng = parseInt(match[2], 10) / 1000;

    // Search reports within 500m of this centroid
    const reports = await fetchActiveSafetyReports({
      latitude: approxLat,
      longitude: approxLng,
      radiusKm: 0.6,
    });

    const clusters = clusterReports(reports);
    let matchedDetails = null;

    for (const cluster of clusters) {
      const details = computeHotspotDetails(cluster);
      if (details && (details.id === id || haversineDistanceMeters(approxLat, approxLng, details.center.latitude, details.center.longitude) <= 400)) {
        matchedDetails = details;
        break;
      }
    }

    if (!matchedDetails) {
      return res.status(404).json({
        success: false,
        message: 'Safety hotspot not found or reports have expired/been resolved.',
      });
    }

    // Fetch recent community comments on reports in this hotspot
    const postIds = matchedDetails.reports.map((r) => r.id);
    let comments = [];
    if (postIds.length > 0) {
      const commentsSql = `
        SELECT c.id, c.post_id, c.content, c.created_at,
               u.full_name AS author_full_name
        FROM community_comments c
        JOIN users u ON u.id = c.user_id
        WHERE c.post_id = ANY($1) AND c.status = 'ACTIVE'
        ORDER BY c.created_at DESC
        LIMIT 10
      `;
      const commResult = await db.query(commentsSql, [postIds]);
      comments = commResult.rows.map((row) => ({
        id: row.id,
        postId: row.post_id,
        content: row.content,
        createdAt: row.created_at,
        authorName: maskAuthorName(row.author_full_name),
      }));
    }

    return res.status(200).json({
      success: true,
      hotspot: {
        ...matchedDetails,
        comments,
      },
      disclaimer:
        'Safety information is based on community reports. Reports may be incomplete or outdated and do not establish that an area is definitely unsafe. Please use your judgment.',
    });
  } catch (error) {
    console.error('[HOTSPOTS] Error fetching hotspot details:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve safety hotspot details.',
      error: error.message,
    });
  }
};

/**
 * POST /api/community/safety-hotspots/:id/feedback
 * Submit verification feedback on a hotspot ('STILL_PRESENT', 'RESOLVED', 'INACCURATE').
 * Enforces one feedback per user per post to prevent manipulation.
 */
const submitHotspotFeedback = async (req, res) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return res.status(401).json({ success: false, message: 'Authentication required.' });
    }

    const { type, postId, comments } = req.body;
    const allowedFeedback = ['STILL_PRESENT', 'RESOLVED', 'INACCURATE'];
    if (!type || !allowedFeedback.includes(type)) {
      return res.status(400).json({
        success: false,
        message: `Feedback type must be one of: ${allowedFeedback.join(', ')}.`,
      });
    }

    let targetPostId = postId;

    // If postId is not provided directly, find the primary post associated with this hotspot ID
    if (!targetPostId) {
      const match = req.params.id.match(/^hotspot_(-?\d+)_(-?\d+)$/);
      if (match) {
        const approxLat = parseInt(match[1], 10) / 1000;
        const approxLng = parseInt(match[2], 10) / 1000;
        const reports = await fetchActiveSafetyReports({
          latitude: approxLat,
          longitude: approxLng,
          radiusKm: 0.5,
        });
        if (reports.length > 0) {
          targetPostId = reports[0].id;
        }
      }
    }

    if (!targetPostId || !isValidUuid(targetPostId)) {
      return res.status(400).json({
        success: false,
        message: 'Valid post ID is required to register verification feedback.',
      });
    }

    // Check if user already submitted feedback for this post
    const existing = await db.query(
      'SELECT id, feedback_type FROM community_post_feedback WHERE post_id = $1 AND user_id = $2',
      [targetPostId, userId]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'You have already submitted feedback for this safety report.',
        existingFeedback: existing.rows[0].feedback_type,
      });
    }

    // Insert feedback record
    await db.query(
      `INSERT INTO community_post_feedback (post_id, user_id, feedback_type, comments)
       VALUES ($1, $2, $3, $4)`,
      [targetPostId, userId, type, comments ? comments.trim().substring(0, 500) : null]
    );

    // Update tallies on post
    if (type === 'STILL_PRESENT') {
      await db.query(
        'UPDATE community_posts SET confirmations_count = confirmations_count + 1 WHERE id = $1',
        [targetPostId]
      );
    } else if (type === 'INACCURATE') {
      await db.query(
        'UPDATE community_posts SET disputes_count = disputes_count + 1 WHERE id = $1',
        [targetPostId]
      );
    } else if (type === 'RESOLVED') {
      await db.query(
        'UPDATE community_posts SET disputes_count = disputes_count + 1 WHERE id = $1',
        [targetPostId]
      );

      // Check if 3 or more users have marked it as resolved
      const resolvedCountResult = await db.query(
        "SELECT COUNT(*) AS count FROM community_post_feedback WHERE post_id = $1 AND feedback_type = 'RESOLVED'",
        [targetPostId]
      );
      const resolvedCount = parseInt(resolvedCountResult.rows[0].count, 10);
      if (resolvedCount >= 3) {
        await db.query(
          "UPDATE community_posts SET resolution_status = 'RESOLVED', resolved_at = NOW() WHERE id = $1",
          [targetPostId]
        );
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Thank you for helping keep the community safe. Your feedback was recorded.',
      feedbackType: type,
    });
  } catch (error) {
    console.error('[HOTSPOTS] Error submitting feedback:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to record hotspot feedback.',
      error: error.message,
    });
  }
};

/**
 * POST /api/community/safety-hotspots/route-check
 * Evaluates route coordinates and current user position against upcoming hotspots.
 */
const checkRouteHotspots = async (req, res) => {
  try {
    const { latitude, longitude, heading, waypoints = [], warningDistanceMeters = 600 } = req.body;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        message: 'latitude and longitude are required in request body.',
      });
    }

    const userLat = parseFloat(latitude);
    const userLng = parseFloat(longitude);
    const radiusKm = Math.min(25, Math.max(1, (warningDistanceMeters * 3) / 1000));

    // Fetch active reports in proximity of user and route
    const reports = await fetchActiveSafetyReports({
      latitude: userLat,
      longitude: userLng,
      radiusKm,
    });

    const clusters = clusterReports(reports);
    const upcomingHotspots = [];

    const userLocation = {
      latitude: userLat,
      longitude: userLng,
      heading: heading !== undefined ? parseFloat(heading) : null,
    };

    for (const cluster of clusters) {
      const hotspot = computeHotspotDetails(cluster);
      if (!hotspot) continue;

      const proximity = evaluateRouteProximity(
        hotspot,
        userLocation,
        waypoints,
        350,
        warningDistanceMeters
      );

      if (proximity.isApproaching) {
        upcomingHotspots.push({
          ...hotspot,
          distanceMeters: proximity.distanceMeters,
          effectiveDistanceMeters: proximity.effectiveDistanceMeters,
          tier: proximity.tier,
        });
      }
    }

    // Sort by closest first
    upcomingHotspots.sort((a, b) => a.distanceMeters - b.distanceMeters);

    return res.status(200).json({
      success: true,
      hasUpcomingHotspots: upcomingHotspots.length > 0,
      upcomingHotspots,
      count: upcomingHotspots.length,
      disclaimer:
        'Safety information is based on community reports. Reports may be incomplete or outdated and do not establish that an area is definitely unsafe. Please use your judgment.',
    });
  } catch (error) {
    console.error('[HOTSPOTS] Error checking route safety:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to evaluate route safety hotspots.',
      error: error.message,
    });
  }
};

module.exports = {
  getPosts,
  getPostById,
  createPost,
  updatePost,
  deletePost,
  upvotePost,
  removeUpvote,
  getComments,
  addComment,
  deleteComment,
  reportPost,
  getMyPosts,
  getSafetyHotspots,
  getNearbyHotspots,
  getHotspotById,
  submitHotspotFeedback,
  checkRouteHotspots,
  ALLOWED_CATEGORIES,
  ALLOWED_REPORT_REASONS,
  maskAuthorName,
  coarsenCoordinate,
};
