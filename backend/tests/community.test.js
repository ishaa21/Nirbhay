require('dotenv').config();
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const db = require('../src/config/db');
const {
  maskAuthorName,
  coarsenCoordinate,
  ALLOWED_CATEGORIES,
  ALLOWED_REPORT_REASONS,
} = require('../src/controllers/communityController');

describe('Community Hub Unit & Integration Tests', () => {
  let testUserId1;
  let testUserId2;
  let testUserToken1;
  let testUserToken2;
  let createdPostId;
  let createdCommentId;

  before(async () => {
    // Clean up any old test users
    await db.query("DELETE FROM users WHERE email IN ('comm_test_user1@nirbhay.local', 'comm_test_user2@nirbhay.local')");

    // Create 2 test users
    const u1 = await db.query(
      `INSERT INTO users (full_name, email, password_hash, phone)
       VALUES ('Priya Sharma', 'comm_test_user1@nirbhay.local', 'mockhash', '+919876543210')
       RETURNING id, full_name, email`
    );
    testUserId1 = u1.rows[0].id;

    const u2 = await db.query(
      `INSERT INTO users (full_name, email, password_hash, phone)
       VALUES ('Rahul Verma', 'comm_test_user2@nirbhay.local', 'mockhash', '+919876543211')
       RETURNING id, full_name, email`
    );
    testUserId2 = u2.rows[0].id;

    const secret = process.env.JWT_SECRET || 'secret';
    testUserToken1 = jwt.sign({ userId: testUserId1, email: 'comm_test_user1@nirbhay.local' }, secret, { expiresIn: '1h' });
    testUserToken2 = jwt.sign({ userId: testUserId2, email: 'comm_test_user2@nirbhay.local' }, secret, { expiresIn: '1h' });
  });

  after(async () => {
    try {
      if (createdPostId) {
        await db.query('DELETE FROM community_posts WHERE id = $1', [createdPostId]);
      }
      if (testUserId1 || testUserId2) {
        await db.query("DELETE FROM users WHERE email IN ('comm_test_user1@nirbhay.local', 'comm_test_user2@nirbhay.local')");
      }
      await db.pool.end();
    } catch (_) {}
  });

  // ── 1. Unit Tests for Privacy & Validation Helpers ─────────────────────────

  test('Privacy helper: maskAuthorName masks full name to First Name + Last Initial', () => {
    assert.equal(maskAuthorName('Priya Sharma'), 'Priya S.');
    assert.equal(maskAuthorName('Rahul M. Verma'), 'Rahul V.');
    assert.equal(maskAuthorName('Ananya'), 'Ananya');
    assert.equal(maskAuthorName(''), 'Nirbhay Member');
    assert.equal(maskAuthorName(null), 'Nirbhay Member');
  });

  test('Privacy helper: coarsenCoordinate rounds GPS to 3 decimals (~110m)', () => {
    assert.equal(coarsenCoordinate(28.6139391), 28.614);
    assert.equal(coarsenCoordinate(77.2090212), 77.209);
    assert.equal(coarsenCoordinate(null), null);
    assert.equal(coarsenCoordinate(''), null);
    assert.equal(coarsenCoordinate('invalid'), null);
  });

  test('Allowed categories and report reasons are correctly enumerated', () => {
    assert.ok(ALLOWED_CATEGORIES.includes('SUSPICIOUS_ACTIVITY'));
    assert.ok(ALLOWED_CATEGORIES.includes('HARASSMENT'));
    assert.ok(ALLOWED_CATEGORIES.includes('UNSAFE_AREA'));
    assert.ok(ALLOWED_CATEGORIES.includes('THEFT'));
    assert.ok(ALLOWED_CATEGORIES.includes('ROAD_SAFETY'));
    assert.ok(ALLOWED_CATEGORIES.includes('LOST_PERSON'));
    assert.ok(ALLOWED_CATEGORIES.includes('HELPFUL_INFO'));
    assert.ok(ALLOWED_CATEGORIES.includes('OTHER'));

    assert.ok(ALLOWED_REPORT_REASONS.includes('INACCURATE'));
    assert.ok(ALLOWED_REPORT_REASONS.includes('ABUSIVE'));
    assert.ok(ALLOWED_REPORT_REASONS.includes('SPAM'));
    assert.ok(ALLOWED_REPORT_REASONS.includes('DANGEROUS'));
    assert.ok(ALLOWED_REPORT_REASONS.includes('DOXXING'));
  });

  // ── 2. Controller Direct API Invocations ────────────────────────────────────

  const communityController = require('../src/controllers/communityController');

  function mockRes() {
    return {
      statusCode: 200,
      jsonData: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.jsonData = data;
        return this;
      },
    };
  }

  test('createPost validates title and description boundaries', async () => {
    // Too short title
    const req1 = {
      userId: testUserId1,
      body: { title: 'ab', description: 'Valid description for testing.', category: 'OTHER' },
    };
    const res1 = mockRes();
    await communityController.createPost(req1, res1);
    assert.equal(res1.statusCode, 400);
    assert.ok(res1.jsonData.message.includes('Title is required and must be at least 3 characters'));

    // Too short description
    const req2 = {
      userId: testUserId1,
      body: { title: 'Valid Title', description: 'Short', category: 'OTHER' },
    };
    const res2 = mockRes();
    await communityController.createPost(req2, res2);
    assert.equal(res2.statusCode, 400);
    assert.ok(res2.jsonData.message.includes('Description is required and must be at least 10 characters'));

    // Invalid category
    const req3 = {
      userId: testUserId1,
      body: { title: 'Valid Title', description: 'Valid long enough description here.', category: 'INVALID_CATEGORY' },
    };
    const res3 = mockRes();
    await communityController.createPost(req3, res3);
    assert.equal(res3.statusCode, 400);
    assert.ok(res3.jsonData.message.includes('Invalid category'));
  });

  test('createPost successfully creates a post with coarsened location', async () => {
    const req = {
      userId: testUserId1,
      body: {
        title: 'Dimly lit pathway near Metro Station',
        description: 'Streetlights on lane 4 are off since evening. Please use lane 2 instead.',
        category: 'UNSAFE_AREA',
        location_name: 'Near Central Metro Station, Gate 2',
        latitude: 28.6139391,
        longitude: 77.2090212,
      },
    };
    const res = mockRes();
    await communityController.createPost(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.jsonData.success, true);
    assert.ok(res.jsonData.post.id);
    assert.equal(res.jsonData.post.title, req.body.title);
    assert.equal(res.jsonData.post.category, 'UNSAFE_AREA');
    // Coarsened coordinates
    assert.equal(res.jsonData.post.latitude, 28.614);
    assert.equal(res.jsonData.post.longitude, 77.209);
    assert.equal(res.jsonData.post.authorName, 'Priya S.');
    assert.equal(res.jsonData.post.isOwner, true);

    createdPostId = res.jsonData.post.id;
  });

  test('getPosts returns paginated feed and includes created post', async () => {
    const req = {
      userId: testUserId1,
      query: { page: '1', limit: '10', category: 'ALL', sort: 'latest' },
    };
    const res = mockRes();
    await communityController.getPosts(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.ok(Array.isArray(res.jsonData.posts));
    assert.ok(res.jsonData.posts.length > 0);
    assert.ok(res.jsonData.pagination.total >= 1);

    const found = res.jsonData.posts.find((p) => p.id === createdPostId);
    assert.ok(found);
    assert.equal(found.isOwner, true);
    assert.equal(found.hasUpvoted, false);
  });

  test('getPostById returns details and comments', async () => {
    const req = {
      userId: testUserId2,
      params: { id: createdPostId },
    };
    const res = mockRes();
    await communityController.getPostById(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.equal(res.jsonData.post.id, createdPostId);
    assert.equal(res.jsonData.post.isOwner, false); // user2 is not owner
    assert.ok(Array.isArray(res.jsonData.post.comments));
  });

  test('upvotePost adds upvote and increments upvotesCount', async () => {
    const req = {
      userId: testUserId2,
      params: { id: createdPostId },
    };
    const res = mockRes();
    await communityController.upvotePost(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.equal(res.jsonData.upvoted, true);
    assert.equal(res.jsonData.upvotesCount, 1);
  });

  test('upvotePost again toggles off upvote and decrements upvotesCount', async () => {
    const req = {
      userId: testUserId2,
      params: { id: createdPostId },
    };
    const res = mockRes();
    await communityController.upvotePost(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.equal(res.jsonData.upvoted, false);
    assert.equal(res.jsonData.upvotesCount, 0);
  });

  test('addComment creates comment and increments commentsCount', async () => {
    const req = {
      userId: testUserId2,
      params: { id: createdPostId },
      body: { content: 'Thank you for the update! Municipal helpline contacted.' },
    };
    const res = mockRes();
    await communityController.addComment(req, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.jsonData.success, true);
    assert.ok(res.jsonData.comment.id);
    assert.equal(res.jsonData.comment.authorName, 'Rahul V.');
    assert.equal(res.jsonData.comment.isOwner, true);

    createdCommentId = res.jsonData.comment.id;

    // Check post comments count
    const postRes = mockRes();
    await communityController.getPostById({ userId: testUserId1, params: { id: createdPostId } }, postRes);
    assert.equal(postRes.jsonData.post.commentsCount, 1);
  });

  test('getComments retrieves the added comment with pagination', async () => {
    const req = {
      userId: testUserId1,
      params: { id: createdPostId },
      query: { page: '1', limit: '20' },
    };
    const res = mockRes();
    await communityController.getComments(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.ok(res.jsonData.comments.length >= 1);
    const comment = res.jsonData.comments.find((c) => c.id === createdCommentId);
    assert.ok(comment);
    assert.equal(comment.content, 'Thank you for the update! Municipal helpline contacted.');
  });

  test('updatePost: non-owner cannot update post (403 Forbidden)', async () => {
    const req = {
      userId: testUserId2, // Not owner
      params: { id: createdPostId },
      body: { title: 'Malicious title modification' },
    };
    const res = mockRes();
    await communityController.updatePost(req, res);

    assert.equal(res.statusCode, 403);
    assert.equal(res.jsonData.success, false);
  });

  test('updatePost: owner can update post title and description', async () => {
    const req = {
      userId: testUserId1, // Owner
      params: { id: createdPostId },
      body: { title: 'Updated: Dimly lit pathway near Metro Station' },
    };
    const res = mockRes();
    await communityController.updatePost(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.equal(res.jsonData.post.title, 'Updated: Dimly lit pathway near Metro Station');
  });

  test('reportPost submits content report and deduplicates per user', async () => {
    const req1 = {
      userId: testUserId2,
      params: { id: createdPostId },
      body: { reason: 'SPAM', details: 'Testing report functionality' },
    };
    const res1 = mockRes();
    await communityController.reportPost(req1, res1);

    assert.equal(res1.statusCode, 200);
    assert.equal(res1.jsonData.success, true);

    // Repeated report by same user should be handled cleanly (deduplicated)
    const res2 = mockRes();
    await communityController.reportPost(req1, res2);
    assert.equal(res2.statusCode, 200);
  });

  test('getMyPosts retrieves only the authenticated user posts', async () => {
    const req = {
      userId: testUserId1,
      query: { page: '1', limit: '10' },
    };
    const res = mockRes();
    await communityController.getMyPosts(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);
    assert.ok(res.jsonData.posts.length >= 1);
    const myPost = res.jsonData.posts.find((p) => p.id === createdPostId);
    assert.ok(myPost);
    assert.equal(myPost.isOwner, true);
  });

  test('deletePost: non-owner cannot delete post (403 Forbidden)', async () => {
    const req = {
      userId: testUserId2,
      params: { id: createdPostId },
    };
    const res = mockRes();
    await communityController.deletePost(req, res);

    assert.equal(res.statusCode, 403);
  });

  test('deletePost: owner can delete post', async () => {
    const req = {
      userId: testUserId1,
      params: { id: createdPostId },
    };
    const res = mockRes();
    await communityController.deletePost(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.jsonData.success, true);

    // Verify it is no longer returned in public feed
    const feedRes = mockRes();
    await communityController.getPosts({ userId: testUserId2, query: { page: '1', limit: '20' } }, feedRes);
    const found = feedRes.jsonData.posts.find((p) => p.id === createdPostId);
    assert.equal(found, undefined);
  });
});
