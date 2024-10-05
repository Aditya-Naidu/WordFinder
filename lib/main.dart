import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

void main() {
  runApp(WordFinderApp());
}

class WordFinderApp extends StatefulWidget {
  @override
  _WordFinderAppState createState() => _WordFinderAppState();
}

class _WordFinderAppState extends State<WordFinderApp> {
  bool _isDarkMode = false;

  void _toggleDarkMode(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Finder',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: WordFinderHomePage(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
      ),
    );
  }
}

class WordFinderHomePage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleDarkMode;

  WordFinderHomePage({
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  _WordFinderHomePageState createState() => _WordFinderHomePageState();
}

class _WordFinderHomePageState extends State<WordFinderHomePage> {
  TextEditingController _controller = TextEditingController();
  Map<int, List<String>> _validWordsByLength = {};
  List<String> _dictionary = [];

  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, List<String>> _cache = {};

  @override
  void initState() {
    super.initState();
    loadDictionary();
  }

  Future<void> loadDictionary() async {
    try {
      String dictData =
      await rootBundle.loadString('assets/dictionary.txt');
      setState(() {
        _dictionary = dictData
            .split('\n')
            .map((word) => word.trim().toLowerCase())
            .where((word) => word.length >= 3)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dictionary: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dictionary.')),
      );
    }
  }

  void _generateValidWords() async {
    String input = _controller.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter at least one letter.')),
      );
      return;
    }

    if (input.length > 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Please enter no more than 9 letters for performance.')),
      );
      return;
    }

    if (_cache.containsKey(input)) {
      _organizeWords(_cache[input]!);
      return;
    }

    setState(() {
      _isProcessing = true;
      _validWordsByLength = {};
    });

    List<String> letters = input.split('');
    Map<String, int> letterCount = {};
    for (var letter in letters) {
      letterCount[letter] = (letterCount[letter] ?? 0) + 1;
    }

    int numIsolates = io.Platform.numberOfProcessors;
    List<List<String>> chunks = _splitList(_dictionary, numIsolates);

    List<Future<List<String>>> futures = [];
    for (var chunk in chunks) {
      WordCheckRequest request = WordCheckRequest(chunk, letterCount);
      futures.add(compute(processWordChunk, request));
    }

    List<List<String>> results = await Future.wait(futures);

    Set<String> validWords = {};
    for (var list in results) {
      validWords.addAll(list);
    }

    List<String> sortedValidWords = validWords.toList()..sort();

    _cache[input] = sortedValidWords;

    _organizeWords(sortedValidWords);

    setState(() {
      _isProcessing = false;
    });
  }

  void _organizeWords(List<String> words) {
    Map<int, List<String>> grouped = {};
    for (String word in words) {
      int len = word.length;
      if (!grouped.containsKey(len)) {
        grouped[len] = [];
      }
      grouped[len]!.add(_capitalize(word));
    }
    setState(() {
      _validWordsByLength = grouped;
    });
  }

  String _capitalize(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }

  List<List<String>> _splitList(List<String> list, int n) {
    List<List<String>> chunks = List.generate(n, (_) => []);
    for (int i = 0; i < list.length; i++) {
      chunks[i % n].add(list[i]);
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Word Finder',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Row(
            children: [
              Icon(
                widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              Switch(
                value: widget.isDarkMode,
                onChanged: widget.onToggleDarkMode,
                activeColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GestureDetector(
        // Dismiss keyboard when tapping outside
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Input Section
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Enter a string (max 9 letters)',
                  border: OutlineInputBorder(),
                  helperText: 'Words can use any subset of the letters',
                  prefixIcon: Icon(Icons.text_fields),
                ),
                maxLength: 9,
                onSubmitted: (_) =>
                _isProcessing ? null : _generateValidWords(),
              ),
              SizedBox(height: 10),
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                  _isProcessing ? null : _generateValidWords,
                  icon: _isProcessing
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2.0,
                    ),
                  )
                      : Icon(Icons.search),
                  label: Text(_isProcessing
                      ? 'Processing...'
                      : 'Find Valid Words'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Results Count
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _validWordsByLength.isNotEmpty
                      ? 'Found ${_validWordsByLength.values.fold(0, (sum, list) => sum + list.length)} valid words'
                      : _isProcessing
                      ? ''
                      : 'No valid words found.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Results Display using ListView with Headers and GridViews
              Expanded(
                child: _isProcessing
                    ? Center(child: CircularProgressIndicator())
                    : _validWordsByLength.isEmpty
                    ? Center(child: Text('No valid words found.'))
                    : ListView.builder(
                  itemCount:
                  _validWordsByLength.keys.length,
                  itemBuilder: (context, index) {
                    int length = _validWordsByLength.keys
                        .elementAt(index);
                    List<String> words =
                    _validWordsByLength[length]!;
                    return Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$length Letters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                          NeverScrollableScrollPhysics(),
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, // Four per row
                            crossAxisSpacing: 10.0,
                            mainAxisSpacing: 10.0,
                            childAspectRatio: 2,
                          ),
                          itemCount: words.length,
                          itemBuilder: (context, idx) {
                            return WordBox(word: words[idx]);
                          },
                        ),
                        SizedBox(height: 15),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data class to pass words and letter counts to the isolate
class WordCheckRequest {
  final List<String> words;
  final Map<String, int> letterCount;

  WordCheckRequest(this.words, this.letterCount);
}

// Top-level function to process a chunk of words in an isolate
Future<List<String>> processWordChunk(WordCheckRequest request) async {
  List<String> validWords = [];
  for (String word in request.words) {
    if (_canFormWord(word, request.letterCount)) {
      validWords.add(word);
    }
  }
  return validWords;
}

// Function to check if a word can be formed from the given letter counts
bool _canFormWord(String word, Map<String, int> letterCount) {
  Map<String, int> wordCount = {};
  for (var letter in word.split('')) {
    wordCount[letter] = (wordCount[letter] ?? 0) + 1;
    if (wordCount[letter]! > (letterCount[letter] ?? 0)) {
      return false;
    }
  }
  return true;
}

// Widget for displaying each word in a styled box
class WordBox extends StatelessWidget {
  final String word;

  const WordBox({Key? key, required this.word}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.teal.shade700
            : Colors.teal.shade100,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.teal),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(1, 2), // changes position of shadow
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        word,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.teal.shade800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
