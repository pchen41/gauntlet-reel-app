import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/lesson_service.dart';
import 'lesson_detail_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({Key? key}) : super(key: key);

  @override
  _LessonsScreenState createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final LessonService _lessonService = LessonService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _recentLessons = [];
  List<Map<String, dynamic>> _allLessons = [];
  Map<String, bool> _bookmarkStatuses = {};
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showBookmarkedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final recentLessons = await _lessonService.getRecentlyViewedLessons(user.uid);
        final allLessons = await _lessonService.getAllLessons();
        
        // Get bookmark statuses for all lessons
        final allLessonIds = [...recentLessons, ...allLessons]
            .map((lesson) => lesson['id'] as String)
            .toSet()
            .toList();
        
        final bookmarkStatuses = await _lessonService.getLessonBookmarkStatuses(
          user.uid,
          allLessonIds,
        );

        if (mounted) {
          setState(() {
            _recentLessons = recentLessons;
            if (_showBookmarkedOnly) {
              _recentLessons = _recentLessons.where((lesson) => 
                _bookmarkStatuses[lesson['id']] ?? false
              ).toList();
            }
            
            _allLessons = _searchQuery.isEmpty 
                ? allLessons 
                : allLessons.where((lesson) => 
                    lesson['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    lesson['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();
            
            if (_showBookmarkedOnly) {
              _allLessons = _allLessons.where((lesson) => 
                _bookmarkStatuses[lesson['id']] ?? false
              ).toList();
            }
            
            _bookmarkStatuses = bookmarkStatuses;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lessons: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBookmark(String lessonId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final isBookmarked = await _lessonService.toggleLessonBookmark(
          user.uid,
          lessonId,
        );
        setState(() {
          _bookmarkStatuses[lessonId] = isBookmarked;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating bookmark: $e')),
          );
        }
      }
    }
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final isBookmarked = _bookmarkStatuses[lesson['id']] ?? false;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16.0, 2, 56.0, 2),
            title: Text(
              lesson['title'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
            subtitle: Text(
              lesson['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonDetailScreen(
                    lessonId: lesson['id'],
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 8,
            child: Center(
              child: GestureDetector(
                onTap: () => _toggleBookmark(lesson['id']),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    color: isBookmarked 
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lessons'),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list),
            offset: const Offset(0, 40),
            initialValue: _showBookmarkedOnly,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2C)
                : null,
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                padding: EdgeInsets.zero,
                height: 40,
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : null,
                  child: StatefulBuilder(
                    builder: (context, setState) => CheckboxListTile(
                      title: Text(
                        'Bookmarked',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      value: _showBookmarkedOnly,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool? value) {
                        this.setState(() {
                          _showBookmarkedOnly = value ?? false;
                          _loadLessons();
                        });
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search lessons...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  setState(() {
                    _searchQuery = value;
                    _loadLessons();
                  });
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadLessons,
                    child: ListView(
                      children: [
                        if (_recentLessons.isNotEmpty && _searchQuery.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
                            child: Text(
                              'Recently Viewed',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._recentLessons.map(_buildLessonCard).toList(),
                          const Padding(
                            padding: EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                            child: Text(
                              'All Lessons',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        ..._allLessons.map(_buildLessonCard).toList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
