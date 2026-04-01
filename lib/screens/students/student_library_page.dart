import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import '/models/student_library_book.dart';
import '/services/student_library_book_service.dart';
import 'student_library_book_detail_page.dart';
import 'package:school_app/services/student_library_checkout_service.dart';
import 'package:school_app/services/library_book_search_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentLibraryPage extends StatefulWidget {
  const StudentLibraryPage({super.key});

  @override
  State<StudentLibraryPage> createState() => _StudentLibraryPageState();
}

class _StudentLibraryPageState extends State<StudentLibraryPage>
    with SingleTickerProviderStateMixin {
  final StudentLibraryCheckoutService _service =
      StudentLibraryCheckoutService();

  late Future<List<StudentLibraryBook>> _allBooks;
  List<StudentLibraryBook>? _searchResults;
  bool _isSearching = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _allBooks = _fetchAndMarkBooks();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<List<StudentLibraryBook>> _fetchAndMarkBooks() async {
    final books = await _service.fetchAllBooks();

    _markBooksAsViewedInBackground(books); // 🔥 don't await

    return books;
  }

  void _markBooksAsViewedInBackground(List<StudentLibraryBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final studentId = prefs.getInt('student_id');

    if (studentId != null) {
      for (var book in books) {
        if (book.id != null) {
          _markLibraryAsViewed(studentId, book.id!, token); // ❌ no await
        }
      }
    }
  }

  Future<void> _markLibraryAsViewed(
    int studentId,
    int bookId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed?studentId=$studentId",
        ),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"item_type": "library", "item_id": bookId}),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Book $bookId marked as viewed");
      } else {
        debugPrint("❌ Failed to mark viewed: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error marking viewed: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSearchDialog() {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final isbnController = TextEditingController();
    final genreController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Search Books"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Title"),
                ),
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: "Author"),
                ),
                TextField(
                  controller: isbnController,
                  decoration: const InputDecoration(labelText: "ISBN"),
                ),
                TextField(
                  controller: genreController,
                  decoration: const InputDecoration(labelText: "Genre"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
              ),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isSearching = true;
                  _searchResults = null;
                });

                try {
                  final results = await LibraryApiService.searchBooks(
                    title: titleController.text.trim().isEmpty
                        ? null
                        : titleController.text.trim(),
                    author: authorController.text.trim().isEmpty
                        ? null
                        : authorController.text.trim(),
                    isbn: isbnController.text.trim().isEmpty
                        ? null
                        : isbnController.text.trim(),
                    genre: genreController.text.trim().isEmpty
                        ? null
                        : genreController.text.trim(),
                  );

                  // Mark search results as viewed also
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('auth_token') ?? '';
                  final studentId = prefs.getInt('student_id');
                  if (studentId != null) {
                    for (var book in results) {
                      if (book.id != null) {
                        await _markLibraryAsViewed(studentId, book.id!, token);
                      }
                    }
                  }

                  setState(() {
                    _searchResults = results;
                    _tabController.animateTo(0);
                  });
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  setState(() => _isSearching = false);
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
              ),
              child: const Text("Search"),
            ),
          ],
        );
      },
    );
  }

  void _clearSearch() {
    setState(() {
      _searchResults = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      body: Container(
        color: const Color(0xFFACCFE2),
        child: Stack(
          children: [
            // Back Button
            Positioned(
              top: 12,
              left: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "< Back",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ),

            // Search Button
            Positioned(
              top: 35,
              right: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Color(0xFF2E3192),
                      size: 40,
                    ),
                    onPressed: _openSearchDialog,
                  ),
                  if (_searchResults != null)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.black,
                        size: 22,
                      ),
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                    ),
                ],
              ),
            ),

            // Title row
            Positioned(
              top: 45,
              left: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF2E3192)),
                    child: SvgPicture.asset(
                      "assets/icons/library.svg",
                      height: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Library",
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                ],
              ),
            ),

            // White container with Tabs
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                margin: const EdgeInsets.only(top: 90),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue,
                      tabs: const [
                        Tab(text: "All Books"),
                        Tab(text: "My Books"),
                        Tab(text: "History"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // All Books (search results or API list)
                          _isSearching
                              ? const Center(child: CircularProgressIndicator())
                              : _searchResults != null
                              ? _buildBookList(_searchResults!)
                              : FutureBuilder<List<StudentLibraryBook>>(
                                  future: _allBooks,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text("Error: ${snapshot.error}"),
                                      );
                                    }
                                    final books = snapshot.data ?? [];
                                    if (books.isEmpty) {
                                      return const Center(
                                        child: Text("No books found."),
                                      );
                                    }
                                    return _buildBookList(books);
                                  },
                                ),

                          // My Books (placeholder)
                          const Center(child: Text("My Books list here")),

                          // History (placeholder)
                          const Center(child: Text("History list here")),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(List<StudentLibraryBook> books) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.green),
            title: Text(
              book.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Author: ${book.author}\nGenre: ${book.genre}\nLocation: ${book.location}",
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Available: ${book.availableQuantity ?? 0}/${book.quantity ?? 0}",
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentBookDetailPage(bookId: book.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
