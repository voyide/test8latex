import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:markdown/markdown.dart' as md;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ExamApp(prefs: prefs));
}

// --- AST MARKDOWN EXTENSIONS FOR INLINE LATEX ---

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'\$([^\$]+)\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex', match[1]!));
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Math.tex(
      element.textContent,
      mathStyle: MathStyle.text,
      textStyle: preferredStyle?.copyWith(fontSize: 16),
    );
  }
}

// --- DATA MODELS ---

class Question {
  final String markdown;
  final String optA, optB, optC, optD, answer;
  String? selectedAnswer;
  int timeSpentSeconds;

  Question({required this.markdown, required this.optA, required this.optB, required this.optC, required this.optD, required this.answer, this.selectedAnswer, this.timeSpentSeconds = 0});

  Map<String, dynamic> toJson() => {'markdown': markdown, 'optA': optA, 'optB': optB, 'optC': optC, 'optD': optD, 'answer': answer, 'selectedAnswer': selectedAnswer, 'timeSpentSeconds': timeSpentSeconds};

  factory Question.fromJson(Map<String, dynamic> json) => Question(markdown: json['markdown'], optA: json['optA'], optB: json['optB'], optC: json['optC'], optD: json['optD'], answer: json['answer'], selectedAnswer: json['selectedAnswer'], timeSpentSeconds: json['timeSpentSeconds'] ?? 0);
}

class Test {
  final String id, category, subcategory;
  final List<Question> questions;
  bool isCompleted;

  Test({required this.id, required this.category, required this.subcategory, required this.questions, this.isCompleted = false});

  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'subcategory': subcategory, 'isCompleted': isCompleted, 'questions': questions.map((q) => q.toJson()).toList()};

  factory Test.fromJson(Map<String, dynamic> json) => Test(id: json['id'], category: json['category'], subcategory: json['subcategory'], isCompleted: json['isCompleted'], questions: (json['questions'] as List).map((q) => Question.fromJson(q)).toList());
}

// --- CORE APP ---

class ExamApp extends StatelessWidget {
  final SharedPreferences prefs;
  const ExamApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brutalist Exam',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEBE3D5), // Beige paper background
        primaryColor: const Color(0xFF1A1A1A), // Almost black
        fontFamily: 'monospace',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEBE3D5),
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
          shape: Border(bottom: BorderSide(color: Color(0xFF1A1A1A), width: 2)),
          titleTextStyle: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'monospace', fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        useMaterial3: false,
      ),
      home: MainNavigation(prefs: prefs),
    );
  }
}

// --- CUSTOM MARKDOWN RENDERER WIDGET ---
// Wraps text so it can parse both standard markdown and inline $latex$
class BrutalistMarkdown extends StatelessWidget {
  final String data;
  const BrutalistMarkdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 16, height: 1.5, fontFamily: 'sans-serif', color: Color(0xFF1A1A1A)),
      ),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        <md.InlineSyntax>[
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          LatexInlineSyntax(),
        ],
      ),
      builders: {'latex': LatexElementBuilder()},
    );
  }
}

// --- MAIN NAVIGATION (BOTTOM TABS) ---

class MainNavigation extends StatefulWidget {
  final SharedPreferences prefs;
  const MainNavigation({super.key, required this.prefs});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  List<Test> tests = [];
  List<String> categoryOrder = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final rawTests = widget.prefs.getString('tests');
    final rawOrder = widget.prefs.getString('categoryOrder');
    
    if (rawTests != null) {
      final List decoded = jsonDecode(rawTests);
      tests = decoded.map((e) => Test.fromJson(e)).toList();
    }
    
    if (rawOrder != null) {
      categoryOrder = List<String>.from(jsonDecode(rawOrder));
    }

    _syncCategories();
  }

  void _syncCategories() {
    Set<String> currentCategories = tests.map((t) => t.category).toSet();
    categoryOrder.removeWhere((c) => !currentCategories.contains(c));
    for (String c in currentCategories) {
      if (!categoryOrder.contains(c)) categoryOrder.add(c);
    }
    _saveData();
    setState(() {});
  }

  void _saveData() {
    widget.prefs.setString('tests', jsonEncode(tests.map((e) => e.toJson()).toList()));
    widget.prefs.setString('categoryOrder', jsonEncode(categoryOrder));
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 2))),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFFEBE3D5),
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF1A1A1A),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'monospace'),
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Tests'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_special_outlined), label: 'Organize'),
          BottomNavigationBarItem(icon: Icon(Icons.input), label: 'Import'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Analysis'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_currentIndex) {
      case 0: body = DirectoryScreen(tests: tests, categoryOrder: categoryOrder, onUpdate: () { _loadData(); }); break;
      case 1: body = OrganizeScreen(categoryOrder: categoryOrder, onReorder: (newOrder) { setState(() { categoryOrder = newOrder; _saveData(); }); }); break;
      case 2: body = ImportScreen(onImport: (t) { tests.add(t); _syncCategories(); }); break;
      case 3: body = GlobalAnalysisScreen(tests: tests); break;
      default: body = Container();
    }

    return Scaffold(body: body, bottomNavigationBar: _buildBottomNav());
  }
}

// --- 1. DIRECTORY SCREEN (HOME) ---

class DirectoryScreen extends StatelessWidget {
  final List<Test> tests;
  final List<String> categoryOrder;
  final VoidCallback onUpdate;

  const DirectoryScreen({super.key, required this.tests, required this.categoryOrder, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INDEX: DIRECTORIES')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categoryOrder.length,
        itemBuilder: (context, index) {
          final cat = categoryOrder[index];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryScreen(category: cat, tests: tests.where((t) => t.category == cat).toList(), onUpdate: onUpdate))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1A1A1A), width: 2)),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: Color(0xFF1A1A1A)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(cat.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2))),
                  const Icon(Icons.chevron_right, color: Color(0xFF1A1A1A)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SubcategoryScreen extends StatelessWidget {
  final String category;
  final List<Test> tests;
  final VoidCallback onUpdate;

  const SubcategoryScreen({super.key, required this.category, required this.tests, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    tests.sort((a, b) => a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1));

    return Scaffold(
      appBar: AppBar(title: Text('DIR: ${category.toUpperCase()}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tests.length,
        itemBuilder: (context, index) {
          final t = tests[index];
          return InkWell(
            onTap: () async {
              if (t.isCompleted) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(test: t, isGlobal: false)));
              } else {
                final prefs = await SharedPreferences.getInstance();
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTestScreen(test: t, prefs: prefs)));
                onUpdate();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1A1A1A), width: 2), color: t.isCompleted ? Colors.black12 : Colors.transparent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.subcategory.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(t.isCompleted ? 'STATUS: COMPLETED' : 'STATUS: PENDING', style: TextStyle(color: t.isCompleted ? Colors.red[900] : Colors.green[900], fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- 2. ORGANIZE SCREEN (DRAG AND DROP) ---

class OrganizeScreen extends StatelessWidget {
  final List<String> categoryOrder;
  final Function(List<String>) onReorder;

  const OrganizeScreen({super.key, required this.categoryOrder, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REORGANIZE (HOLD & DRAG)')),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categoryOrder.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          final List<String> newOrder = List.from(categoryOrder);
          final item = newOrder.removeAt(oldIndex);
          newOrder.insert(newIndex, item);
          onReorder(newOrder);
        },
        itemBuilder: (context, index) {
          return Container(
            key: ValueKey(categoryOrder[index]),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1A1A1A), width: 2), color: const Color(0xFFEBE3D5)),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator),
                const SizedBox(width: 16),
                Text(categoryOrder[index].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- 3. IMPORT SCREEN ---

class ImportScreen extends StatefulWidget {
  final Function(Test) onImport;
  const ImportScreen({super.key, required this.onImport});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ctrlData = TextEditingController();

  void _processImport() {
    try {
      final raw = ctrlData.text;
      String extractGlobal(String tag, String nextTag) {
        if (!raw.contains(tag)) return 'UNKNOWN';
        int start = raw.indexOf(tag) + tag.length;
        int end = raw.contains(nextTag) ? raw.indexOf(nextTag) : raw.length;
        return raw.substring(start, end).trim();
      }

      final category = extractGlobal('@@CATEGORY@@', '@@SUBCATEGORY@@');
      final subcategory = extractGlobal('@@SUBCATEGORY@@', '===BEGIN_QUESTION===');
      final blocks = raw.split('===BEGIN_QUESTION===');
      List<Question> parsedQuestions = [];

      for (int i = 1; i < blocks.length; i++) {
        var block = blocks[i].replaceAll('===END_QUESTION===', '').trim();
        if (block.isEmpty) continue;
        
        String extract(String tag, String nextTag) {
          if (!block.contains(tag)) return '';
          int start = block.indexOf(tag) + tag.length;
          int end = nextTag.isNotEmpty && block.contains(nextTag) ? block.indexOf(nextTag) : block.length;
          return block.substring(start, end).trim();
        }

        final md = extract('@@MARKDOWN@@', '@@OPT_A@@');
        final a = extract('@@OPT_A@@', '@@OPT_B@@');
        final b = extract('@@OPT_B@@', '@@OPT_C@@');
        final c = extract('@@OPT_C@@', '@@OPT_D@@');
        final d = extract('@@OPT_D@@', '@@ANSWER@@');
        final ans = extract('@@ANSWER@@', '').trim().toUpperCase();

        if (md.isNotEmpty && ans.isNotEmpty) {
          parsedQuestions.add(Question(markdown: md, optA: a, optB: b, optC: c, optD: d, answer: ans));
        }
      }

      if (parsedQuestions.isNotEmpty) {
        widget.onImport(Test(id: DateTime.now().millisecondsSinceEpoch.toString(), category: category, subcategory: subcategory, questions: parsedQuestions));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IMPORT SUCCESSFUL')));
        ctrlData.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PARSE ERROR. CHECK SYNTAX.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMPORT TERMINAL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('PASTE RAW DATA BELOW (INCLUDE @@CATEGORY@@ AND @@SUBCATEGORY@@ HEADERS)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrlData, maxLines: 20,
              decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 2))),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _processImport,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: const Color(0xFF1A1A1A)),
              child: const Text('EXECUTE IMPORT', style: TextStyle(color: Color(0xFFEBE3D5), fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. ACTIVE TEST SCREEN (UI CLONED FROM IMAGE) ---

class ActiveTestScreen extends StatefulWidget {
  final Test test;
  final SharedPreferences prefs;
  const ActiveTestScreen({super.key, required this.test, required this.prefs});

  @override
  State<ActiveTestScreen> createState() => _ActiveTestScreenState();
}

class _ActiveTestScreenState extends State<ActiveTestScreen> {
  int currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted) setState(() { widget.test.questions[currentIndex].timeSpentSeconds++; });
      if (timer.tick % 5 == 0) _persistState(); 
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _persistState() {
    final raw = widget.prefs.getString('tests');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      final List<Test> allTests = decoded.map((e) => Test.fromJson(e)).toList();
      final index = allTests.indexWhere((t) => t.id == widget.test.id);
      if (index != -1) {
        allTests[index] = widget.test;
        widget.prefs.setString('tests', jsonEncode(allTests.map((e) => e.toJson()).toList()));
      }
    }
  }

  void _submitTest() {
    widget.test.isCompleted = true;
    _persistState();
    Navigator.pop(context);
  }

  Widget _buildOption(String label, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    final q = widget.test.questions[currentIndex];
    final isSelected = q.selectedAnswer == label;
    return InkWell(
      onTap: () { setState(() => q.selectedAnswer = label); _persistState(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A).withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Expanded(child: BrutalistMarkdown(data: text)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.test.questions[currentIndex];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(width: 2, color: Color(0xFF1A1A1A)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Q: ${currentIndex + 1}/${widget.test.questions.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1)),
                  Text('TIME: ${q.timeSpentSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1)),
                ],
              ),
            ),
            // QUESTION CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BrutalistMarkdown(data: q.markdown),
                    const SizedBox(height: 32),
                    _buildOption('A', q.optA),
                    _buildOption('B', q.optB),
                    _buildOption('C', q.optC),
                    _buildOption('D', q.optD),
                  ],
                ),
              ),
            ),
            // NAVIGATION GRID & SUBMIT (BOTTOM ALIGNED)
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(width: 2, color: Color(0xFF1A1A1A)))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80,
                    padding: const EdgeInsets.all(12),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.test.questions.length,
                      itemBuilder: (context, idx) {
                        final isAns = widget.test.questions[idx].selectedAnswer != null;
                        return InkWell(
                          onTap: () => setState(() => currentIndex = idx),
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: currentIndex == idx ? const Color(0xFF6B8E8E) : (isAns ? Colors.black12 : const Color(0xFFEBE3D5)),
                              border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text('${idx + 1}', style: TextStyle(color: currentIndex == idx ? Colors.white : const Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        );
                      },
                    ),
                  ),
                  InkWell(
                    onTap: _submitTest,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFF2B2B2B),
                      alignment: Alignment.center,
                      child: const Text('SUBMIT TEST', style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. ANALYSIS SCREEN ---

class AnalysisScreen extends StatefulWidget {
  final Test? test;
  final bool isGlobal;
  final List<Question>? allQuestions;
  const AnalysisScreen({super.key, this.test, required this.isGlobal, this.allQuestions});
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String sortMode = 'DEFAULT'; 
  late List<Question> displayQuestions;

  @override
  void initState() {
    super.initState();
    displayQuestions = widget.isGlobal ? List.from(widget.allQuestions!) : List.from(widget.test!.questions);
    _applySort();
  }

  void _applySort() {
    setState(() {
      if (sortMode == 'TIME_ASC') displayQuestions.sort((a, b) => a.timeSpentSeconds.compareTo(b.timeSpentSeconds));
      else if (sortMode == 'TIME_DESC') displayQuestions.sort((a, b) => b.timeSpentSeconds.compareTo(a.timeSpentSeconds));
      else {
        displayQuestions.sort((a, b) {
          bool aCorrect = a.selectedAnswer == a.answer;
          bool bCorrect = b.selectedAnswer == b.answer;
          if (aCorrect == bCorrect) return 0;
          return aCorrect ? 1 : -1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGlobal ? 'GLOBAL STATS' : 'TEST STATS'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) { sortMode = val; _applySort(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'DEFAULT', child: Text('SORT: CORRECTNESS')),
              const PopupMenuItem(value: 'TIME_ASC', child: Text('SORT: FASTEST')),
              const PopupMenuItem(value: 'TIME_DESC', child: Text('SORT: SLOWEST')),
            ],
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayQuestions.length,
        itemBuilder: (context, index) {
          final q = displayQuestions[index];
          final isCorrect = q.selectedAnswer == q.answer;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1A1A1A), width: 2), color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCorrect ? 'STATUS: CORRECT' : 'STATUS: INCORRECT', style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green[900] : Colors.red[900])),
                Text('TIME: ${q.timeSpentSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(color: Color(0xFF1A1A1A), thickness: 2, height: 24),
                BrutalistMarkdown(data: q.markdown),
                const SizedBox(height: 16),
                Text('YOUR ANSWER: ${q.selectedAnswer ?? 'NONE'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('CORRECT ANSWER: ${q.answer}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GlobalAnalysisScreen extends StatelessWidget {
  final List<Test> tests;
  const GlobalAnalysisScreen({super.key, required this.tests});

  @override
  Widget build(BuildContext context) {
    List<Question> allQuestions = [];
    for (var t in tests.where((t) => t.isCompleted)) { allQuestions.addAll(t.questions); }
    if (allQuestions.isEmpty) return const Scaffold(body: Center(child: Text('NO COMPLETED TESTS', style: TextStyle(fontWeight: FontWeight.bold))));
    return AnalysisScreen(isGlobal: true, allQuestions: allQuestions);
  }
}
