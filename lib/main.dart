import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ExamApp(prefs: prefs));
}

// --- DATA MODELS ---

class Question {
  final String markdown;
  final String math;
  final String optA;
  final String optB;
  final String optC;
  final String optD;
  final String answer;
  String? selectedAnswer;
  int timeSpentSeconds;

  Question({
    required this.markdown, required this.math, required this.optA,
    required this.optB, required this.optC, required this.optD,
    required this.answer, this.selectedAnswer, this.timeSpentSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
    'markdown': markdown, 'math': math, 'optA': optA, 'optB': optB,
    'optC': optC, 'optD': optD, 'answer': answer,
    'selectedAnswer': selectedAnswer, 'timeSpentSeconds': timeSpentSeconds,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    markdown: json['markdown'], math: json['math'], optA: json['optA'],
    optB: json['optB'], optC: json['optC'], optD: json['optD'],
    answer: json['answer'], selectedAnswer: json['selectedAnswer'],
    timeSpentSeconds: json['timeSpentSeconds'] ?? 0,
  );
}

class Test {
  final String id;
  final String category;
  final String subcategory;
  final List<Question> questions;
  bool isCompleted;

  Test({required this.id, required this.category, required this.subcategory, required this.questions, this.isCompleted = false});

  Map<String, dynamic> toJson() => {
    'id': id, 'category': category, 'subcategory': subcategory, 'isCompleted': isCompleted,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  factory Test.fromJson(Map<String, dynamic> json) => Test(
    id: json['id'], category: json['category'], subcategory: json['subcategory'],
    isCompleted: json['isCompleted'],
    questions: (json['questions'] as List).map((q) => Question.fromJson(q)).toList(),
  );
}

// --- CORE APP & STATE ---

class ExamApp extends StatelessWidget {
  final SharedPreferences prefs;
  const ExamApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brutalist Exam',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE2DACC), // Aged paper
        primaryColor: const Color(0xFF2B2B2B), // Industrial dark
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE2DACC),
          foregroundColor: Color(0xFF2B2B2B),
          elevation: 0,
          shape: Border(bottom: BorderSide(color: Color(0xFF2B2B2B), width: 3)),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFFE2DACC),
          elevation: 0,
          shape: RoundedRectangleBorder(side: BorderSide(color: Color(0xFF2B2B2B), width: 2), borderRadius: BorderRadius.zero),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B2B2B),
            foregroundColor: const Color(0xFFE2DACC),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            side: const BorderSide(color: Color(0xFF2B2B2B), width: 2),
          ),
        ),
        useMaterial3: false, // Disables M3 rounded corners defaults
      ),
      home: HomeScreen(prefs: prefs),
    );
  }
}

// --- HOME SCREEN (ORGANIZATION) ---

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const HomeScreen({super.key, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Test> tests = [];

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  void _loadTests() {
    final raw = widget.prefs.getString('tests');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() => tests = decoded.map((e) => Test.fromJson(e)).toList());
    }
  }

  void _saveTests() {
    widget.prefs.setString('tests', jsonEncode(tests.map((e) => e.toJson()).toList()));
    _loadTests();
  }

  void _deleteTest(String id) {
    setState(() => tests.removeWhere((t) => t.id == id));
    _saveTests();
  }

  @override
  Widget build(BuildContext context) {
    tests.sort((a, b) => a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1));

    return Scaffold(
      appBar: AppBar(title: const Text('EXAM // REPOSITORY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tests.length,
        itemBuilder: (context, index) {
          final t = tests[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2B2B2B), width: 3)),
            child: ListTile(
              title: Text('${t.category} > ${t.subcategory}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(t.isCompleted ? 'STATUS: COMPLETED' : 'STATUS: INCOMPLETE', 
                style: TextStyle(color: t.isCompleted ? Colors.red[900] : Colors.green[900], fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Color(0xFF2B2B2B)), onPressed: () => _deleteTest(t.id)),
              onTap: () async {
                if (t.isCompleted) {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisScreen(test: t, isGlobal: false)));
                } else {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTestScreen(test: t, prefs: widget.prefs)));
                  _loadTests(); // Refresh after test
                }
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(width: 3))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ImportScreen(onImport: (t) { tests.add(t); _saveTests(); })));
            }, child: const Text('IMPORT RAW')),
            ElevatedButton(onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalAnalysisScreen(tests: tests.where((t) => t.isCompleted).toList())));
            }, child: const Text('GLOBAL STATS')),
          ],
        ),
      ),
    );
  }
}

// --- IMPORT SCREEN (PARSER) ---

class ImportScreen extends StatefulWidget {
  final Function(Test) onImport;
  const ImportScreen({super.key, required this.onImport});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ctrlCat = TextEditingController();
  final ctrlSub = TextEditingController();
  final ctrlData = TextEditingController();

  final template = '''===BEGIN_QUESTION===
@@MARKDOWN@@
Question Text
@@MATH@@
\\LaTeX_Equation_Here
@@OPT_A@@
Option A text
@@OPT_B@@
Option B text
@@OPT_C@@
Option C text
@@OPT_D@@
Option D text
@@ANSWER@@
A
===END_QUESTION===''';

  void _processImport() {
    try {
      final raw = ctrlData.text;
      final blocks = raw.split('===BEGIN_QUESTION===');
      List<Question> parsedQuestions = [];

      for (var block in blocks) {
        if (block.trim().isEmpty) continue;
        block = block.replaceAll('===END_QUESTION===', '').trim();
        
        String extract(String tag, String nextTag) {
          if (!block.contains(tag)) return '';
          int start = block.indexOf(tag) + tag.length;
          int end = nextTag.isNotEmpty && block.contains(nextTag) ? block.indexOf(nextTag) : block.length;
          return block.substring(start, end).trim();
        }

        final md = extract('@@MARKDOWN@@', '@@MATH@@');
        final math = extract('@@MATH@@', '@@OPT_A@@');
        final a = extract('@@OPT_A@@', '@@OPT_B@@');
        final b = extract('@@OPT_B@@', '@@OPT_C@@');
        final c = extract('@@OPT_C@@', '@@OPT_D@@');
        final d = extract('@@OPT_D@@', '@@ANSWER@@');
        final ans = extract('@@ANSWER@@', '').trim().toUpperCase();

        if (md.isNotEmpty && ans.isNotEmpty) {
          parsedQuestions.add(Question(markdown: md, math: math, optA: a, optB: b, optC: c, optD: d, answer: ans));
        }
      }

      if (parsedQuestions.isNotEmpty && ctrlCat.text.isNotEmpty) {
        widget.onImport(Test(id: DateTime.now().millisecondsSinceEpoch.toString(), category: ctrlCat.text, subcategory: ctrlSub.text, questions: parsedQuestions));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PARSE ERROR. CHECK SYNTAX.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMPORT DATA // TERMINAL')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: ctrlCat, decoration: const InputDecoration(labelText: 'CATEGORY', border: OutlineInputBorder(borderRadius: BorderRadius.zero))),
            const SizedBox(height: 16),
            TextField(controller: ctrlSub, decoration: const InputDecoration(labelText: 'SUBCATEGORY', border: OutlineInputBorder(borderRadius: BorderRadius.zero))),
            const SizedBox(height: 16),
            SelectableText('TEMPLATE:\n$template', style: const TextStyle(fontFamily: 'monospace', backgroundColor: Colors.black12)),
            const SizedBox(height: 16),
            TextField(controller: ctrlData, maxLines: 15, decoration: const InputDecoration(labelText: 'PASTE RAW DATA', border: OutlineInputBorder(borderRadius: BorderRadius.zero))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _processImport, child: const Text('EXECUTE IMPORT')),
          ],
        ),
      ),
    );
  }
}

// --- ACTIVE TEST SCREEN (IIT STYLE UI) ---

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
      setState(() {
        widget.test.questions[currentIndex].timeSpentSeconds++;
      });
      if (timer.tick % 5 == 0) _persistState(); // Auto-save every 5 seconds
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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

  Future<bool> _onWillPop() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('WARNING'),
        content: const Text('EXITING WILL SAVE CURRENT PROGRESS. CONTINUE?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCEL', style: TextStyle(color: Colors.black))),
          TextButton(onPressed: () { _persistState(); Navigator.of(context).pop(true); }, child: const Text('EXIT', style: TextStyle(color: Colors.black))),
        ],
      ),
    ) ?? false;
  }

  Widget _buildOption(String label, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    final q = widget.test.questions[currentIndex];
    final isSelected = q.selectedAnswer == label;
    return InkWell(
      onTap: () {
        setState(() => q.selectedAnswer = label);
        _persistState();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B2B2B) : Colors.transparent,
          border: Border.all(color: const Color(0xFF2B2B2B), width: 2),
        ),
        child: Row(
          children: [
            Text('$label. ', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFE2DACC) : const Color(0xFF2B2B2B))),
            Expanded(child: Text(text, style: TextStyle(color: isSelected ? const Color(0xFFE2DACC) : const Color(0xFF2B2B2B)))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.test.questions[currentIndex];
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(width: 3))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Q: ${currentIndex + 1}/${widget.test.questions.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('TIME: ${q.timeSpentSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 18)),
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
                      if (q.markdown.isNotEmpty) MarkdownBody(data: q.markdown),
                      const SizedBox(height: 16),
                      if (q.math.isNotEmpty) 
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Math.tex(q.math, textStyle: const TextStyle(fontSize: 18)),
                        ),
                      const SizedBox(height: 32),
                      _buildOption('A', q.optA),
                      _buildOption('B', q.optB),
                      _buildOption('C', q.optC),
                      _buildOption('D', q.optD),
                    ],
                  ),
                ),
              ),
              // NAVIGATION GRID
              Container(
                height: 120,
                decoration: const BoxDecoration(border: Border(top: BorderSide(width: 3))),
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 4, mainAxisSpacing: 4),
                  itemCount: widget.test.questions.length,
                  itemBuilder: (context, idx) {
                    final isAns = widget.test.questions[idx].selectedAnswer != null;
                    return InkWell(
                      onTap: () => setState(() => currentIndex = idx),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentIndex == idx ? Colors.blueGrey : (isAns ? const Color(0xFF2B2B2B) : Colors.transparent),
                          border: Border.all(color: const Color(0xFF2B2B2B), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text('${idx + 1}', style: TextStyle(color: (isAns || currentIndex == idx) ? const Color(0xFFE2DACC) : const Color(0xFF2B2B2B), fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              // FOOTER CONTROLS
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => _submitTest(), child: const Text('SUBMIT TEST'))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- ANALYSIS SCREEN (SINGLE & GLOBAL) ---

class AnalysisScreen extends StatefulWidget {
  final Test? test;
  final bool isGlobal;
  final List<Question>? allQuestions;

  const AnalysisScreen({super.key, this.test, required this.isGlobal, this.allQuestions});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String sortMode = 'DEFAULT'; // DEFAULT, TIME_ASC, TIME_DESC
  late List<Question> displayQuestions;

  @override
  void initState() {
    super.initState();
    displayQuestions = widget.isGlobal ? List.from(widget.allQuestions!) : List.from(widget.test!.questions);
    _applySort();
  }

  void _applySort() {
    setState(() {
      if (sortMode == 'TIME_ASC') {
        displayQuestions.sort((a, b) => a.timeSpentSeconds.compareTo(b.timeSpentSeconds));
      } else if (sortMode == 'TIME_DESC') {
        displayQuestions.sort((a, b) => b.timeSpentSeconds.compareTo(a.timeSpentSeconds));
      } else {
        // DEFAULT: Incorrect top, Correct bottom. Unanswered go to incorrect.
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
        title: Text(widget.isGlobal ? 'GLOBAL ANALYSIS' : 'TEST ANALYSIS'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) { sortMode = val; _applySort(); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'DEFAULT', child: Text('SORT: CORRECTNESS')),
              const PopupMenuItem(value: 'TIME_ASC', child: Text('SORT: TIME (FASTEST)')),
              const PopupMenuItem(value: 'TIME_DESC', child: Text('SORT: TIME (SLOWEST)')),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2B2B2B), width: 3),
              color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isCorrect ? 'STATUS: CORRECT' : 'STATUS: INCORRECT', style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green[900] : Colors.red[900])),
                    Text('TIME: ${q.timeSpentSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Color(0xFF2B2B2B), thickness: 2),
                if (q.markdown.isNotEmpty) MarkdownBody(data: q.markdown),
                if (q.math.isNotEmpty) 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Math.tex(q.math)),
                  ),
                const SizedBox(height: 8),
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
    for (var t in tests) { allQuestions.addAll(t.questions); }
    
    if (allQuestions.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('GLOBAL ANALYSIS')), body: const Center(child: Text('NO COMPLETED DATA', style: TextStyle(fontWeight: FontWeight.bold))));
    }

    return AnalysisScreen(isGlobal: true, allQuestions: allQuestions);
  }
}
