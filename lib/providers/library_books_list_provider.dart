import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/library_book_service.dart';

class LibraryBooksListProvider extends ChangeNotifier {
  final LibraryBookService _service = LibraryBookService();

  bool isLoading = false;
  String? error;
  List<dynamic> books = [];

  // Cache mechanism
  static const String _booksCacheKey = 'cached_books';
  static const String _lastFetchTimeKey = 'last_fetch_time';
  static const Duration _cacheDuration = Duration(
    minutes: 5,
  ); // Cache for 5 minutes

  DateTime? _lastFetchTime;
  bool _isInitialized = false;
  bool _isLoadingCache = false;

  LibraryBooksListProvider() {
    // Use a microtask to avoid calling notifyListeners during build
    Future.microtask(() => _loadCachedBooks());
  }

  Future<void> _loadCachedBooks() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingCache) return;
    _isLoadingCache = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached books
      final cachedBooksJson = prefs.getString(_booksCacheKey);
      if (cachedBooksJson != null) {
        books = jsonDecode(cachedBooksJson) as List<dynamic>;
        // Only notify if there are listeners and not during build
        if (hasListeners) {
          notifyListeners();
        }
      }

      // Load last fetch time
      final lastFetchTimeStr = prefs.getString(_lastFetchTimeKey);
      if (lastFetchTimeStr != null) {
        _lastFetchTime = DateTime.parse(lastFetchTimeStr);
      }

      _isInitialized = true;

      // Check if cache is expired and fetch if needed
      if (_isCacheExpired()) {
        // Use a microtask to avoid calling during build
        Future.microtask(() => fetchBooks(forceRefresh: false));
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading cached books: $e");
      }
    } finally {
      _isLoadingCache = false;
    }
  }

  bool _isCacheExpired() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheDuration;
  }

  Future<void> _saveBooksToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_booksCacheKey, jsonEncode(books));
      await prefs.setString(
        _lastFetchTimeKey,
        DateTime.now().toIso8601String(),
      );
      _lastFetchTime = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        print("Error saving books to cache: $e");
      }
    }
  }

  Future<void> fetchBooks({bool forceRefresh = false}) async {
    // Don't fetch if already loading
    if (isLoading) return;

    // Check if we have cached data that's still valid
    if (!forceRefresh && !_isCacheExpired() && books.isNotEmpty) {
      if (kDebugMode) {
        print("Using cached books data");
      }
      return;
    }

    isLoading = true;
    error = null;
    // Only notify if there are listeners
    if (hasListeners) {
      notifyListeners();
    }

    try {
      // Add timeout to prevent hanging
      final result = await _service.getAllBooks().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception("Request timeout - please try again");
        },
      );

      books = result;
      await _saveBooksToCache();

      if (kDebugMode) {
        print("Successfully fetched ${books.length} books");
      }
    } catch (e) {
      error = e.toString();
      if (kDebugMode) {
        print("Error fetching books: $e");
      }
    } finally {
      isLoading = false;
      // Only notify if there are listeners
      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // Optional: Add manual refresh method
  Future<void> refreshBooks() async {
    await fetchBooks(forceRefresh: true);
  }

  // Optional: Add search functionality
  List<dynamic> searchBooks(String query) {
    if (query.isEmpty) return books;

    final lowercaseQuery = query.toLowerCase();
    return books.where((book) {
      final title = book['title']?.toString().toLowerCase() ?? '';
      final author = book['author']?.toString().toLowerCase() ?? '';
      final isbn = book['isbn']?.toString().toLowerCase() ?? '';

      return title.contains(lowercaseQuery) ||
          author.contains(lowercaseQuery) ||
          isbn.contains(lowercaseQuery);
    }).toList();
  }

  // Optional: Add method to get book by ID
  dynamic getBookById(int id) {
    try {
      return books.firstWhere((book) => book['id'] == id);
    } catch (e) {
      return null;
    }
  }
}
