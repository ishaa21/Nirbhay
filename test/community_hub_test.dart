import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/models/community_post_model.dart';
import 'package:nirbhay/screens/community_screen.dart';

void main() {
  group('CommunityCategory Model Tests', () {
    test('All enum values provide correct apiKey, label, icon, and color', () {
      for (final cat in CommunityCategory.values) {
        expect(cat.apiKey, isNotEmpty);
        expect(cat.label, isNotEmpty);
        expect(cat.icon, isNotNull);
        expect(cat.color, isNotNull);
      }

      expect(CommunityCategory.suspiciousActivity.apiKey, 'SUSPICIOUS_ACTIVITY');
      expect(CommunityCategory.harassment.apiKey, 'HARASSMENT');
      expect(CommunityCategory.unsafeArea.apiKey, 'UNSAFE_AREA');
      expect(CommunityCategory.theft.apiKey, 'THEFT');
      expect(CommunityCategory.roadSafety.apiKey, 'ROAD_SAFETY');
      expect(CommunityCategory.lostPerson.apiKey, 'LOST_PERSON');
      expect(CommunityCategory.helpfulInfo.apiKey, 'HELPFUL_INFO');
      expect(CommunityCategory.other.apiKey, 'OTHER');
    });

    test('CommunityCategoryExtension.fromString parses valid strings and falls back gracefully', () {
      expect(CommunityCategoryExtension.fromString('SUSPICIOUS_ACTIVITY'), CommunityCategory.suspiciousActivity);
      expect(CommunityCategoryExtension.fromString('harassment'), CommunityCategory.harassment);
      expect(CommunityCategoryExtension.fromString('UNSAFE_AREA'), CommunityCategory.unsafeArea);
      expect(CommunityCategoryExtension.fromString('THEFT'), CommunityCategory.theft);
      expect(CommunityCategoryExtension.fromString('ROAD_SAFETY'), CommunityCategory.roadSafety);
      expect(CommunityCategoryExtension.fromString('LOST_PERSON'), CommunityCategory.lostPerson);
      expect(CommunityCategoryExtension.fromString('HELPFUL_INFO'), CommunityCategory.helpfulInfo);
      expect(CommunityCategoryExtension.fromString('OTHER'), CommunityCategory.other);
      expect(CommunityCategoryExtension.fromString('UNKNOWN_STRING'), CommunityCategory.other);
      expect(CommunityCategoryExtension.fromString(null), CommunityCategory.other);
    });
  });

  group('CommunityComment Model Tests', () {
    test('fromJSON and toJSON correctly serializes comment fields', () {
      final json = {
        'id': 'comm-123',
        'content': 'Police reached the crossing and secured the area.',
        'authorName': 'Rahul V.',
        'authorId': 'user-456',
        'createdAt': '2026-10-21T18:30:00.000Z',
        'isOwner': true,
      };

      final comment = CommunityComment.fromJson(json);
      expect(comment.id, 'comm-123');
      expect(comment.content, 'Police reached the crossing and secured the area.');
      expect(comment.authorName, 'Rahul V.');
      expect(comment.authorId, 'user-456');
      expect(comment.isOwner, true);

      final encoded = comment.toJson();
      expect(encoded['id'], 'comm-123');
      expect(encoded['content'], 'Police reached the crossing and secured the area.');
      expect(encoded['isOwner'], true);
    });

    test('fromJSON handles null / fallback fields without crashing', () {
      final comment = CommunityComment.fromJson({});
      expect(comment.id, '');
      expect(comment.content, '');
      expect(comment.authorName, 'Nirbhay Member');
      expect(comment.isOwner, false);
      expect(comment.createdAt, isNotNull);
    });
  });

  group('CommunityPost Model Tests', () {
    test('fromJSON correctly maps post fields and nested comments', () {
      final json = {
        'id': 'post-789',
        'category': 'UNSAFE_AREA',
        'title': 'Broken street lamps in Sector 14',
        'description': 'Main market alleyway is completely dark after 7 PM.',
        'locationName': 'Sector 14 Market Crossing',
        'latitude': 28.614,
        'longitude': 77.209,
        'upvotesCount': 15,
        'commentsCount': 2,
        'authorName': 'Priya S.',
        'authorId': 'author-101',
        'createdAt': '2026-10-21T17:00:00.000Z',
        'distanceKm': 1.25,
        'hasUpvoted': true,
        'isOwner': false,
        'comments': [
          {
            'id': 'c-1',
            'content': 'Confirmed, took detour today.',
            'authorName': 'Ananya K.',
            'authorId': 'u-2',
            'createdAt': '2026-10-21T17:30:00.000Z',
            'isOwner': false,
          }
        ],
      };

      final post = CommunityPost.fromJson(json);
      expect(post.id, 'post-789');
      expect(post.category, CommunityCategory.unsafeArea);
      expect(post.title, 'Broken street lamps in Sector 14');
      expect(post.description, 'Main market alleyway is completely dark after 7 PM.');
      expect(post.locationName, 'Sector 14 Market Crossing');
      expect(post.latitude, 28.614);
      expect(post.longitude, 77.209);
      expect(post.upvotesCount, 15);
      expect(post.commentsCount, 2);
      expect(post.authorName, 'Priya S.');
      expect(post.distanceKm, 1.25);
      expect(post.hasUpvoted, true);
      expect(post.isOwner, false);
      expect(post.comments.length, 1);
      expect(post.comments.first.content, 'Confirmed, took detour today.');
    });

    test('copyWith properly updates mutable fields like upvote and commentsCount', () {
      final post = CommunityPost(
        id: 'post-1',
        category: CommunityCategory.roadSafety,
        title: 'Waterlogging near underpass',
        description: 'Vehicles cannot pass safely.',
        upvotesCount: 5,
        commentsCount: 1,
        authorName: 'Sneha M.',
        authorId: 'u-1',
        createdAt: DateTime.now(),
        hasUpvoted: false,
      );

      final updated = post.copyWith(
        upvotesCount: 6,
        hasUpvoted: true,
        commentsCount: 2,
      );

      expect(updated.id, 'post-1');
      expect(updated.title, 'Waterlogging near underpass');
      expect(updated.upvotesCount, 6);
      expect(updated.hasUpvoted, true);
      expect(updated.commentsCount, 2);
    });
  });

  group('CommunityScreen Widget Tests', () {
    testWidgets('Renders Community Hub UI with header, CTA banner, and filter controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityScreen(),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Community Hub'), findsOneWidget);
      expect(find.text('Neighborhood safety alerts & verified updates'), findsOneWidget);

      // Verify "Report a Safety Concern" banner
      expect(find.text('Report a Safety Concern'), findsOneWidget);
      expect(find.text('Alert people nearby about harassment, hazards, or unsafe spots.'), findsOneWidget);

      // Verify Tab Switcher
      expect(find.text('Community Alerts'), findsOneWidget);
      expect(find.text('My Reports'), findsOneWidget);

      // Verify Sort Chips
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Most Upvoted'), findsOneWidget);

      // Verify Floating Action Button
      expect(find.text('Post Report'), findsOneWidget);
    });

    testWidgets('Tapping My Reports switches active view', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityScreen(),
          ),
        ),
      );

      // Initially on Community Alerts
      expect(find.text('Latest'), findsOneWidget);

      // Tap "My Reports"
      await tester.tap(find.text('My Reports'));
      await tester.pump();

      // On My Reports, the sort and category sub-filters are hidden
      expect(find.text('Latest'), findsNothing);
      expect(find.text('Most Upvoted'), findsNothing);
    });
  });
}
