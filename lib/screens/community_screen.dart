import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  // ── Color tokens ────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _cardBorder = Color(0x1A301427);

  // ── State variables ─────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 1;
  bool _hasMore = false;

  // Filter & Sort State
  String _selectedCategory = 'ALL';
  String _selectedSort = 'latest'; // 'latest', 'nearby', 'most_upvoted'
  bool _isMyPostsView = false;

  Position? _currentPosition;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed(resetPage: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMorePosts();
      }
    }
  }

  // ── Data Fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchFeed({bool resetPage = false}) async {
    if (resetPage) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      Map<String, dynamic> res;

      if (_isMyPostsView) {
        res = await CommunityService().getMyPosts(page: _currentPage, limit: 15);
      } else {
        res = await CommunityService().getPosts(
          page: _currentPage,
          limit: 15,
          category: _selectedCategory,
          sort: _selectedSort,
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
        );
      }

      if (!mounted) return;

      if (res['success'] == true) {
        final List<CommunityPost> loaded = res['posts'] as List<CommunityPost>? ?? [];
        setState(() {
          _posts = loaded;
          _hasMore = res['hasMore'] as bool? ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message'] ?? 'Failed to load safety alerts.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection error. Please pull to refresh.';
      });
    }
  }

  Future<void> _loadMorePosts() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;

    try {
      Map<String, dynamic> res;
      if (_isMyPostsView) {
        res = await CommunityService().getMyPosts(page: nextPage, limit: 15);
      } else {
        res = await CommunityService().getPosts(
          page: nextPage,
          limit: 15,
          category: _selectedCategory,
          sort: _selectedSort,
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
        );
      }

      if (!mounted) return;

      if (res['success'] == true) {
        final List<CommunityPost> loaded = res['posts'] as List<CommunityPost>? ?? [];
        setState(() {
          _currentPage = nextPage;
          _posts.addAll(loaded);
          _hasMore = res['hasMore'] as bool? ?? false;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _requestNearbyLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable device location to view nearby alerts.')),
        );
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required to sort alerts by proximity.')),
          );
          setState(() => _isLocating = false);
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _selectedSort = 'nearby';
        _isLocating = false;
      });
      _fetchFeed(resetPage: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not obtain location: $e')),
      );
    }
  }

  // ── Upvote Handler ─────────────────────────────────────────────────────────

  Future<void> _handleToggleUpvote(CommunityPost post) async {
    final oldUpvoted = post.hasUpvoted;
    final oldCount = post.upvotesCount;
    final newUpvoted = !oldUpvoted;
    final newCount = newUpvoted ? oldCount + 1 : (oldCount > 0 ? oldCount - 1 : 0);

    // Optimistic UI update
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index] = post.copyWith(
          hasUpvoted: newUpvoted,
          upvotesCount: newCount,
        );
      }
    });

    final res = await CommunityService().toggleUpvote(post.id);
    if (!mounted) return;

    if (res['success'] != true) {
      // Revert optimistic update on failure
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = post.copyWith(
            hasUpvoted: oldUpvoted,
            upvotesCount: oldCount,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Could not update vote.')),
      );
    } else {
      // Confirm with exact server counts
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
            hasUpvoted: res['upvoted'] as bool? ?? newUpvoted,
            upvotesCount: res['upvotesCount'] as int? ?? newCount,
          );
        }
      });
    }
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: () => _fetchFeed(resetPage: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Header & Action Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildReportIncidentCTA(),
                      const SizedBox(height: 16),
                      _buildViewSwitcher(),
                      if (!_isMyPostsView) ...[
                        const SizedBox(height: 12),
                        _buildSortFilterRow(),
                        const SizedBox(height: 12),
                        _buildCategoryFilterCarousel(),
                      ],
                    ],
                  ),
                ),
              ),

              // Post Feed List
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildPostCard(_posts[index]),
                        );
                      },
                      childCount: _posts.length,
                    ),
                  ),
                ),
                if (_isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostSheet,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post Report', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Header & Navigation ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Community Hub',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _primary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Neighborhood safety alerts & verified updates',
              style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _fetchFeed(resetPage: true),
          icon: const Icon(Icons.refresh_rounded, color: _primary),
        ),
      ],
    );
  }

  Widget _buildReportIncidentCTA() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF301427), Color(0xFF4A203C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showCreatePostSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_alert_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Report a Safety Concern',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Alert people nearby about harassment, hazards, or unsafe spots.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFE2D0DC)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isMyPostsView) {
                  setState(() => _isMyPostsView = false);
                  _fetchFeed(resetPage: true);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isMyPostsView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: !_isMyPostsView
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Community Alerts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: !_isMyPostsView ? _primary : _onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isMyPostsView) {
                  setState(() => _isMyPostsView = true);
                  _fetchFeed(resetPage: true);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isMyPostsView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _isMyPostsView
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'My Reports',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isMyPostsView ? _primary : _onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSortChip(
            label: 'Latest',
            icon: Icons.access_time_rounded,
            isSelected: _selectedSort == 'latest',
            onTap: () {
              if (_selectedSort != 'latest') {
                setState(() => _selectedSort = 'latest');
                _fetchFeed(resetPage: true);
              }
            },
          ),
          const SizedBox(width: 8),
          _buildSortChip(
            label: _isLocating ? 'Locating...' : 'Nearby',
            icon: Icons.near_me_outlined,
            isSelected: _selectedSort == 'nearby',
            onTap: () {
              if (_currentPosition != null) {
                if (_selectedSort != 'nearby') {
                  setState(() => _selectedSort = 'nearby');
                  _fetchFeed(resetPage: true);
                }
              } else {
                _requestNearbyLocation();
              }
            },
          ),
          const SizedBox(width: 8),
          _buildSortChip(
            label: 'Most Upvoted',
            icon: Icons.thumb_up_alt_outlined,
            isSelected: _selectedSort == 'most_upvoted',
            onTap: () {
              if (_selectedSort != 'most_upvoted') {
                setState(() => _selectedSort = 'most_upvoted');
                _fetchFeed(resetPage: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primary : _cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : _onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterCarousel() {
    final categories = [
      {'key': 'ALL', 'label': 'All', 'icon': Icons.apps_rounded},
      {'key': 'SUSPICIOUS_ACTIVITY', 'label': 'Suspicious Activity', 'icon': Icons.visibility_outlined},
      {'key': 'HARASSMENT', 'label': 'Harassment', 'icon': Icons.shield_outlined},
      {'key': 'UNSAFE_AREA', 'label': 'Unsafe Area', 'icon': Icons.warning_amber_rounded},
      {'key': 'THEFT', 'label': 'Theft', 'icon': Icons.lock_outline},
      {'key': 'ROAD_SAFETY', 'label': 'Road Safety', 'icon': Icons.traffic_outlined},
      {'key': 'LOST_PERSON', 'label': 'Lost Person', 'icon': Icons.person_search_outlined},
      {'key': 'HELPFUL_INFO', 'label': 'Helpful Info', 'icon': Icons.info_outline},
      {'key': 'OTHER', 'label': 'Other', 'icon': Icons.category_outlined},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat['key'];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (_selectedCategory != cat['key']) {
                setState(() => _selectedCategory = cat['key'] as String);
                _fetchFeed(resetPage: true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _secondaryContainer : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? _primary.withOpacity(0.5) : _cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 15,
                    color: isSelected ? _primary : _onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _primary : _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Post Card ──────────────────────────────────────────────────────────────

  Widget _buildPostCard(CommunityPost post) {
    final catColor = post.category.color;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPostDetailsModal(post),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(post.category.icon, size: 13, color: catColor),
                          const SizedBox(width: 4),
                          Text(
                            post.category.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatRelativeTime(post.createdAt),
                      style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: _onSurfaceVariant),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'report') {
                          _showReportPostDialog(post.id);
                        } else if (val == 'edit') {
                          _showEditPostSheet(post);
                        } else if (val == 'delete') {
                          _confirmDeletePost(post.id);
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (post.isOwner) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: _primary),
                                SizedBox(width: 8),
                                Text('Edit Report'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Color(0xFFBA1A1A)),
                                SizedBox(width: 8),
                                Text('Delete Report', style: TextStyle(color: Color(0xFFBA1A1A))),
                              ],
                            ),
                          ),
                        ] else ...[
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 18, color: Color(0xFFBA1A1A)),
                                SizedBox(width: 8),
                                Text('Report Inappropriate'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Post Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),

                // Post Description
                Text(
                  post.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _onSurface,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Location Badge (if coarse location was attached)
                if (post.locationName != null || post.distanceKm != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: _onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.locationName != null && post.distanceKm != null
                              ? '${post.locationName} (${post.distanceKm!.toStringAsFixed(1)} km away)'
                              : (post.locationName ?? '${post.distanceKm!.toStringAsFixed(1)} km away'),
                          style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                const Divider(height: 1, color: _cardBorder),
                const SizedBox(height: 8),

                // Footer Row: Author, Upvote, Comments
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 14, color: _onSecondaryContainer),
                    const SizedBox(width: 4),
                    Text(
                      post.authorName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _onSecondaryContainer),
                    ),
                    const Spacer(),
                    // Upvote button
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _handleToggleUpvote(post),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              post.hasUpvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                              size: 16,
                              color: post.hasUpvoted ? _primary : _onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.upvotesCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: post.hasUpvoted ? FontWeight.bold : FontWeight.normal,
                                color: post.hasUpvoted ? _primary : _onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Comments button
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openPostDetailsModal(post),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.mode_comment_outlined, size: 16, color: _onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${post.commentsCount}',
                              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Modals & Dialogs ───────────────────────────────────────────────────────

  void _openPostDetailsModal(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PostDetailsSheet(
        initialPost: post,
        onPostUpdated: (updated) {
          setState(() {
            final idx = _posts.indexWhere((p) => p.id == updated.id);
            if (idx != -1) _posts[idx] = updated;
          });
        },
        onPostDeleted: (deletedId) {
          setState(() {
            _posts.removeWhere((p) => p.id == deletedId);
          });
        },
      ),
    );
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreatePostSheet(
        onPostCreated: (newPost) {
          setState(() {
            _posts.insert(0, newPost);
          });
        },
      ),
    );
  }

  void _showEditPostSheet(CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPostSheet(
        post: post,
        onPostUpdated: (updated) {
          setState(() {
            final idx = _posts.indexWhere((p) => p.id == updated.id);
            if (idx != -1) _posts[idx] = updated;
          });
        },
      ),
    );
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Safety Report?'),
        content: const Text('Are you sure you want to remove this report from the community feed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A)),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await CommunityService().deletePost(postId);
              if (!mounted) return;
              if (res['success'] == true) {
                setState(() => _posts.removeWhere((p) => p.id == postId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report deleted successfully.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Failed to delete report.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportPostDialog(String postId) {
    String selectedReason = 'INACCURATE';
    final detailsController = TextEditingController();
    final scaffold = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Report Inappropriate Content', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help keep Nirbhay reliable and safe. Select the primary reason for reporting this post:',
                  style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  title: const Text('Inaccurate or False Info', style: TextStyle(fontSize: 13)),
                  value: 'INACCURATE',
                  groupValue: selectedReason,
                  activeColor: _primary,
                  onChanged: (val) => setDialogState(() => selectedReason = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Harassment or Abusive', style: TextStyle(fontSize: 13)),
                  value: 'ABUSIVE',
                  groupValue: selectedReason,
                  activeColor: _primary,
                  onChanged: (val) => setDialogState(() => selectedReason = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Spam or Advertising', style: TextStyle(fontSize: 13)),
                  value: 'SPAM',
                  groupValue: selectedReason,
                  activeColor: _primary,
                  onChanged: (val) => setDialogState(() => selectedReason = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Dangerous or Incitement', style: TextStyle(fontSize: 13)),
                  value: 'DANGEROUS',
                  groupValue: selectedReason,
                  activeColor: _primary,
                  onChanged: (val) => setDialogState(() => selectedReason = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Doxxing / Personal Phone Numbers', style: TextStyle(fontSize: 13)),
                  value: 'DOXXING',
                  groupValue: selectedReason,
                  activeColor: _primary,
                  onChanged: (val) => setDialogState(() => selectedReason = val!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A)),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await CommunityService().reportPost(
                  postId,
                  reason: selectedReason,
                  details: detailsController.text.trim(),
                );
                scaffold.showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Report received.')),
                );
              },
              child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty & Error States ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 36, color: _primary),
            ),
            const SizedBox(height: 16),
            Text(
              _isMyPostsView ? 'No Reports Yet' : 'No Alerts in this Category',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
            ),
            const SizedBox(height: 6),
            Text(
              _isMyPostsView
                  ? 'Reports you share about local safety and road hazards will appear here.'
                  : 'Be the first in your area to share a safety notice or helpful community tip.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreatePostSheet,
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('Post Safety Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFBA1A1A)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to load safety alerts.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _fetchFeed(resetPage: true),
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post Details & Comments Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PostDetailsSheet extends StatefulWidget {
  final CommunityPost initialPost;
  final ValueChanged<CommunityPost> onPostUpdated;
  final ValueChanged<String> onPostDeleted;

  const _PostDetailsSheet({
    required this.initialPost,
    required this.onPostUpdated,
    required this.onPostDeleted,
  });

  @override
  State<_PostDetailsSheet> createState() => _PostDetailsSheetState();
}

class _PostDetailsSheetState extends State<_PostDetailsSheet> {
  late CommunityPost _post;
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;
  List<CommunityComment> _comments = [];
  bool _isLoadingComments = true;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _comments = List.from(widget.initialPost.comments);
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final res = await CommunityService().getComments(_post.id);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _comments = res['comments'] as List<CommunityComment>? ?? [];
        _isLoadingComments = false;
      });
    } else {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingComment = true);
    final res = await CommunityService().addComment(_post.id, text);
    if (!mounted) return;

    setState(() => _isPostingComment = false);

    if (res['success'] == true && res['comment'] != null) {
      _commentController.clear();
      final newComment = res['comment'] as CommunityComment;
      setState(() {
        _comments.add(newComment);
        _post = _post.copyWith(commentsCount: _post.commentsCount + 1);
      });
      widget.onPostUpdated(_post);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to post comment.')),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final res = await CommunityService().deleteComment(_post.id, commentId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
        _post = _post.copyWith(
          commentsCount: _post.commentsCount > 0 ? _post.commentsCount - 1 : 0,
        );
      });
      widget.onPostUpdated(_post);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to delete comment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Scrollable Post details & comments list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                // Category & Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _post.category.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(_post.category.icon, size: 14, color: _post.category.color),
                          const SizedBox(width: 4),
                          Text(
                            _post.category.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _post.category.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDateTime(_post.createdAt),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4E4449)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  _post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF301427),
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  _post.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF1B1B1C),
                  ),
                ),
                const SizedBox(height: 14),

                // Location Banner (if coarsened location exists)
                if (_post.locationName != null || _post.latitude != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2D9E4).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A301427)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFF301427)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _post.locationName ?? 'Approximate Area',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Author & Upvotes info
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 16, color: Color(0xFF705D67)),
                    const SizedBox(width: 6),
                    Text(
                      'Reported by ${_post.authorName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF705D67)),
                    ),
                    const Spacer(),
                    const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Color(0xFF4E4449)),
                    const SizedBox(width: 4),
                    Text(
                      '${_post.upvotesCount} upvotes',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4E4449)),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Comments Header
                Row(
                  children: [
                    const Text(
                      'Community Discussion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF301427),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${_comments.length})',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4E4449)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Comments List
                if (_isLoadingComments)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFF301427)),
                    ),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No comments yet. Share an update or helpful info below.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF4E4449)),
                      ),
                    ),
                  )
                else
                  ..._comments.map((comment) => _buildCommentItem(comment)),
              ],
            ),
          ),

          // Comment Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0x1A301427))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Add a comment or safety update...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF4E4449)),
                      filled: true,
                      fillColor: const Color(0xFFF6F3F4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF301427),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isPostingComment ? null : _submitComment,
                  icon: _isPostingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommunityComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment.authorName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF301427),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(comment.createdAt),
                style: const TextStyle(fontSize: 10, color: Color(0xFF4E4449)),
              ),
              if (comment.isOwner) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _deleteComment(comment.id),
                  child: const Icon(Icons.close, size: 14, color: Color(0xFFBA1A1A)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comment.content,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1B1B1C)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Safety Report Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  final ValueChanged<CommunityPost> onPostCreated;

  const _CreatePostSheet({required this.onPostCreated});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  CommunityCategory _selectedCategory = CommunityCategory.suspiciousActivity;
  bool _attachLocation = false;
  Position? _acquiredPosition;
  bool _isLocating = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleLocationToggle(bool val) async {
    setState(() => _attachLocation = val);
    if (val && _acquiredPosition == null) {
      setState(() => _isLocating = true);
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
        if (!mounted) return;
        setState(() {
          _acquiredPosition = pos;
          _isLocating = false;
        });
      } catch (_) {
        if (mounted) setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a descriptive title (at least 3 characters).')),
      );
      return;
    }

    if (description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the concern (at least 10 characters).')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await CommunityService().createPost(
      title: title,
      description: description,
      category: _selectedCategory.apiKey,
      locationName: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      latitude: _attachLocation ? _acquiredPosition?.latitude : null,
      longitude: _attachLocation ? _acquiredPosition?.longitude : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true && res['post'] != null) {
      Navigator.pop(context);
      widget.onPostCreated(res['post'] as CommunityPost);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safety alert published to community.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to submit report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: Color(0xFF301427), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Post Safety Alert',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Incident Category',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CommunityCategory.values.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 14, color: isSel ? Colors.white : cat.color),
                          const SizedBox(width: 4),
                          Text(cat.label),
                        ],
                      ),
                      selected: isSel,
                      selectedColor: const Color(0xFF301427),
                      backgroundColor: const Color(0xFFF6F3F4),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSel ? Colors.white : const Color(0xFF1B1B1C),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Title',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'e.g., Streetlight out on 5th Avenue',
                    filled: true,
                    fillColor: const Color(0xFFF6F3F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Description',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 3000,
                  decoration: InputDecoration(
                    hintText: 'Provide helpful, objective details to help people navigate safely...',
                    filled: true,
                    fillColor: const Color(0xFFF6F3F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Location Details (Optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _locationController,
                  maxLength: 255,
                  decoration: InputDecoration(
                    hintText: 'e.g., Near Rajiv Chowk Gate 4',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF705D67)),
                    filled: true,
                    fillColor: const Color(0xFFF6F3F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: const Text('Attach Coarse GPS Coordinates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'Allows nearby users to view distance. Coarsened to ~110m to protect privacy.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF4E4449)),
                  ),
                  value: _attachLocation,
                  activeColor: const Color(0xFF301427),
                  contentPadding: EdgeInsets.zero,
                  onChanged: _handleLocationToggle,
                ),
                if (_isLocating) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: LinearProgressIndicator(minHeight: 2, color: Color(0xFF301427)),
                  ),
                ],
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF301427),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Publish Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Safety Report Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditPostSheet extends StatefulWidget {
  final CommunityPost post;
  final ValueChanged<CommunityPost> onPostUpdated;

  const _EditPostSheet({required this.post, required this.onPostUpdated});

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late CommunityCategory _selectedCategory;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _descriptionController = TextEditingController(text: widget.post.description);
    _selectedCategory = widget.post.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.length < 3 || description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title (3+ chars) and description (10+ chars) are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await CommunityService().updatePost(
      id: widget.post.id,
      title: title,
      description: description,
      category: _selectedCategory.apiKey,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true && res['post'] != null) {
      Navigator.pop(context);
      widget.onPostUpdated(res['post'] as CommunityPost);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report updated successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to update report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Edit Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF301427)),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CommunityCategory.values.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat.label),
                      selected: isSel,
                      selectedColor: const Color(0xFF301427),
                      labelStyle: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF6F3F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF6F3F4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _updatePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF301427),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
