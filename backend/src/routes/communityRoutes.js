const express = require('express');
const router = express.Router();
const communityController = require('../controllers/communityController');
const authenticateToken = require('../middleware/authMiddleware');
const optionalAuth = require('../middleware/optionalAuthMiddleware');

// ── Public / Optional Auth Routes ──────────────────────────────────────────
// List posts with pagination, category filter, sort, and nearby location radius
router.get('/posts', optionalAuth, communityController.getPosts);

// Authenticated user's own posts (MUST precede /posts/:id so "my-posts" is not parsed as :id)
router.get('/my-posts', authenticateToken, communityController.getMyPosts);

// Single post details
router.get('/posts/:id', optionalAuth, communityController.getPostById);

// Comments list for a post
router.get('/posts/:id/comments', optionalAuth, communityController.getComments);

// ── Safety Hotspots & Heatmap Routes ──────────────────────────────────────
// Query safety hotspots (bounds or radius)
router.get('/safety-hotspots', optionalAuth, communityController.getSafetyHotspots);

// Nearby safety hotspots (latitude, longitude, radiusMeters)
router.get('/safety-hotspots/nearby', optionalAuth, communityController.getNearbyHotspots);

// Evaluate route waypoints against upcoming safety hotspots
router.post('/safety-hotspots/route-check', optionalAuth, communityController.checkRouteHotspots);

// Single safety hotspot details by ID
router.get('/safety-hotspots/:id', optionalAuth, communityController.getHotspotById);

// Submit community verification / dispute feedback on hotspot (protected)
router.post('/safety-hotspots/:id/feedback', authenticateToken, communityController.submitHotspotFeedback);

// ── Protected Routes (Require JWT Token) ───────────────────────────────────
// Create new report / post
router.post('/posts', authenticateToken, communityController.createPost);

// Edit author's own post
router.patch('/posts/:id', authenticateToken, communityController.updatePost);

// Delete author's own post
router.delete('/posts/:id', authenticateToken, communityController.deletePost);

// Upvote post (add / toggle)
router.post('/posts/:id/upvote', authenticateToken, communityController.upvotePost);

// Explicitly remove upvote
router.delete('/posts/:id/upvote', authenticateToken, communityController.removeUpvote);

// Add comment to post
router.post('/posts/:id/comments', authenticateToken, communityController.addComment);

// Delete author's own comment
router.delete('/posts/:id/comments/:commentId', authenticateToken, communityController.deleteComment);

// Report post content (flag inappropriate/dangerous content)
router.post('/posts/:id/report', authenticateToken, communityController.reportPost);

module.exports = router;
