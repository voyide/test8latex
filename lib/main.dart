import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState()..initSystem())],
      child: const ProTestApp(),
    ),
  );
}

// ==========================================
// AST MARKDOWN EXTENSIONS FOR LATEX
// ==========================================
class BlockLatexSyntax extends md.InlineSyntax {
  BlockLatexSyntax() : super(r'\$\$([^\$]+)\$\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex_block', match[1]!));
    return true;
  }
}

class InlineLatexSyntax extends md.InlineSyntax {
  InlineLatexSyntax() : super(r'\$([^\$]+)\$');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex_inline', match[1]!));
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  final MathStyle mathStyle;
  LatexElementBuilder({required this.mathStyle});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Math.tex(
      element.textContent,
      mathStyle: mathStyle,
      textStyle: preferredStyle?.copyWith(fontSize: 16),
    );
  }
}

class BrutalistMarkdown extends StatelessWidget {
  final String data;
  const BrutalistMarkdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeBg = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final codeText = isDark ? Colors.grey.shade100 : Colors.black87;

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.bold, color: inkBlack),
        code: TextStyle(backgroundColor: codeBg, color: codeText, fontFamily: 'monospace', fontSize: 16),
        codeblockDecoration: BoxDecoration(color: codeBg, borderRadius: BorderRadius.zero),
      ),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        <md.InlineSyntax>[
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          BlockLatexSyntax(),
          InlineLatexSyntax(),
        ],
      ),
      builders: {
        'latex_block': LatexElementBuilder(mathStyle: MathStyle.display),
        'latex_inline': LatexElementBuilder(mathStyle: MathStyle.text),
      },
    );
  }
}

// ==========================================
// THEME: BRUTALIST PAPER AESTHETIC
// ==========================================
final Color paperBg = const Color(0xFFE0D4EB); // Light Purple
final Color inkBlack = const Color(0xFF1E1E1E);
final Color brassAccent = const Color(0xFFB58840);
final Color rustRed = const Color(0xFF9E3C27);
final Color steamGreen = const Color(0xFF385E38);

final ThemeData brutalistTheme = ThemeData(
  fontFamily: 'Courier',
  scaffoldBackgroundColor: paperBg,
  colorScheme: ColorScheme.light(
    primary: inkBlack, secondary: brassAccent, surface: paperBg,
    error: rustRed, onPrimary: paperBg, onSecondary: inkBlack, onSurface: inkBlack,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: paperBg, foregroundColor: inkBlack, elevation: 0, centerTitle: true,
    shape: Border(bottom: BorderSide(color: inkBlack, width: 3)),
  ),
  cardTheme: CardTheme(
    color: paperBg, elevation: 0, margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: inkBlack, width: 2)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: inkBlack, foregroundColor: paperBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(color: inkBlack, width: 2), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: inkBlack,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(color: inkBlack, width: 2), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: paperBg,
    border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black, width: 2)),
    enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black, width: 2)),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black, width: 3)),
  ),
  dialogTheme: DialogTheme(backgroundColor: paperBg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: Colors.black, width: 3))),
  drawerTheme: DrawerThemeData(backgroundColor: paperBg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: Colors.black, width: 2))),
  dividerTheme: DividerThemeData(color: inkBlack, thickness: 2),
);

class ProTestApp extends StatelessWidget {
  const ProTestApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'ProTest', debugShowCheckedModeBanner: false, theme: brutalistTheme, home: const MainNavigationScreen());
  }
}

// ==========================================
// MODELS
// ==========================================
class UserProfile {
  final String id;
  final String name;
  UserProfile({required this.id, required this.name});
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(id: json['id'], name: json['name']);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Question {
  final String id;
  String category;
  String subCategory;
  String text;
  List<String> options;
  int correctAnswerIndex;
  Question({required this.id, required this.category, required this.subCategory, required this.text, required this.options, required this.correctAnswerIndex});
  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    category: json['category'] ?? 'Uncategorized', subCategory: json['subCategory'] ?? 'General',
    text: json['text'] ?? '', options: List<String>.from(json['options'] ?? []), correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
  );
  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'subCategory': subCategory, 'text': text, 'options': options, 'correctAnswerIndex': correctAnswerIndex};
}

class TestSession {
  final String id;
  String category; 
  String subCategory; 
  final int score;
  final int totalQuestions;
  final int durationSeconds;
  final int timestamp;
  final List<Question> questions;
  final Map<String, int> userAnswers;
  final Map<String, int> timePerQuestion;

  TestSession({required this.id, required this.category, required this.subCategory, required this.score, required this.totalQuestions, required this.durationSeconds, required this.timestamp, required this.questions, required this.userAnswers, required this.timePerQuestion});
  factory TestSession.fromJson(Map<String, dynamic> json) => TestSession(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    category: json['category'] ?? '', subCategory: json['subCategory'] ?? '',
    score: json['score'] ?? 0, totalQuestions: json['totalQuestions'] ?? 0,
    durationSeconds: json['durationSeconds'] ?? 0, timestamp: json['timestamp'] ?? 0,
    questions: (json['questions'] as List<dynamic>?)?.map((q) => Question.fromJson(q)).toList() ?? [],
    userAnswers: Map<String, int>.from(json['userAnswers'] ?? {}),
    timePerQuestion: Map<String, int>.from(json['timePerQuestion'] ?? {}),
  );
  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'subCategory': subCategory, 'score': score, 'totalQuestions': totalQuestions, 'durationSeconds': durationSeconds, 'timestamp': timestamp, 'questions': questions.map((q) => q.toJson()).toList(), 'userAnswers': userAnswers, 'timePerQuestion': timePerQuestion};
}

class ActiveTestState {
  final Map<String, int> answers;
  final Map<String, int> times;
  final Map<String, int> statuses;
  final int totalElapsed;
  ActiveTestState({required this.answers, required this.times, required this.statuses, required this.totalElapsed});
  factory ActiveTestState.fromJson(Map<String, dynamic> json) => ActiveTestState(
    answers: Map<String, int>.from(json['answers'] ?? {}), times: Map<String, int>.from(json['times'] ?? {}),
    statuses: Map<String, int>.from(json['statuses'] ?? {}), totalElapsed: json['totalElapsed'] ?? 0);
  Map<String, dynamic> toJson() => {'answers': answers, 'times': times, 'statuses': statuses, 'totalElapsed': totalElapsed};
}

enum QuestionStatus { notVisited, notAnswered, answered, markedForReview, answeredAndMarked }
enum SortMode { defaultOrder, timeAsc, timeDesc }

// ==========================================
// STATE MANAGEMENT (PROVIDER)
// ==========================================
class AppState extends ChangeNotifier {
  List<UserProfile> _users = [];
  UserProfile? _currentUser;
  List<Question> _questions = [];
  List<TestSession> _sessions = [];
  Map<String, ActiveTestState> _activeStates = {};
  List<String> _categoryOrder = [];
  Map<String, List<String>> _subCategoryOrder = {};
  bool _isLoading = true;

  List<UserProfile> get users => _users;
  UserProfile? get currentUser => _currentUser;
  List<Question> get questions => _questions;
  List<TestSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> initSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('sys_users');
    if (usersJson != null) {
      _users = (jsonDecode(usersJson) as List).map((u) => UserProfile.fromJson(u)).toList();
    }
    if (_users.isEmpty) {
      _users.add(UserProfile(id: 'usr_${DateTime.now().millisecondsSinceEpoch}', name: 'OPERATOR_01'));
      await prefs.setString('sys_users', jsonEncode(_users.map((u) => u.toJson()).toList()));
    }
    
    final lastUserId = prefs.getString('last_user_id') ?? _users.first.id;
    _currentUser = _users.firstWhere((u) => u.id == lastUserId, orElse: () => _users.first);
    
    await loadUserData(_currentUser!.id);
  }

  Future<void> createUser(String name) async {
    final newUser = UserProfile(id: 'usr_${DateTime.now().millisecondsSinceEpoch}', name: name);
    _users.add(newUser);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sys_users', jsonEncode(_users.map((u) => u.toJson()).toList()));
    notifyListeners();
  }

  Future<void> switchUser(String id) async {
    _isLoading = true;
    notifyListeners();
    _currentUser = _users.firstWhere((u) => u.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_id', _currentUser!.id);
    await loadUserData(_currentUser!.id);
  }

  Future<void> loadUserData(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final qJson = prefs.getString('q_$uid');
    _questions = qJson != null ? (jsonDecode(qJson) as List).map((q) => Question.fromJson(q)).toList() : [];

    final sJson = prefs.getString('s_$uid');
    _sessions = sJson != null ? (jsonDecode(sJson) as List).map((s) => TestSession.fromJson(s)).toList() : [];

    final aJson = prefs.getString('act_$uid');
    if (aJson != null) {
      Map<String, dynamic> decoded = jsonDecode(aJson);
      _activeStates = decoded.map((k, v) => MapEntry(k, ActiveTestState.fromJson(v)));
    } else { _activeStates = {}; }

    final catOrder = prefs.getString('catOrd_$uid');
    _categoryOrder = catOrder != null ? List<String>.from(jsonDecode(catOrder)) : [];

    final subCatOrder = prefs.getString('subCatOrd_$uid');
    if (subCatOrder != null) {
      Map<String, dynamic> dec = jsonDecode(subCatOrder);
      _subCategoryOrder = dec.map((k, v) => MapEntry(k, List<String>.from(v)));
    } else { _subCategoryOrder = {}; }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveUserData() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('q_$uid', jsonEncode(_questions.map((q) => q.toJson()).toList()));
    await prefs.setString('s_$uid', jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    await prefs.setString('act_$uid', jsonEncode(_activeStates.map((k, v) => MapEntry(k, v.toJson()))));
    await prefs.setString('catOrd_$uid', jsonEncode(_categoryOrder));
    await prefs.setString('subCatOrd_$uid', jsonEncode(_subCategoryOrder));
  }

  // File Organizers & Order logic
  List<String> getCategories() {
    Set<String> existing = _questions.map((q) => q.category).toSet();
    _categoryOrder.removeWhere((c) => !existing.contains(c));
    for (var c in existing) { if (!_categoryOrder.contains(c)) _categoryOrder.add(c); }
    saveUserData();
    return List.from(_categoryOrder);
  }

  void reorderCategory(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx -= 1;
    final item = _categoryOrder.removeAt(oldIdx);
    _categoryOrder.insert(newIdx, item);
    saveUserData(); notifyListeners();
  }

  List<String> getSubCategories(String cat) {
    Set<String> existing = _questions.where((q) => q.category == cat).map((q) => q.subCategory).toSet();
    if (!_subCategoryOrder.containsKey(cat)) _subCategoryOrder[cat] = [];
    _subCategoryOrder[cat]!.removeWhere((c) => !existing.contains(c));
    for (var c in existing) { if (!_subCategoryOrder[cat]!.contains(c)) _subCategoryOrder[cat]!.add(c); }
    saveUserData();
    return List.from(_subCategoryOrder[cat]!);
  }

  void moveSubCategoryUp(String cat, String subCat) {
    List<String> list = _subCategoryOrder[cat]!;
    int idx = list.indexOf(subCat);
    if (idx > 0) { list.removeAt(idx); list.insert(idx - 1, subCat); saveUserData(); notifyListeners(); }
  }

  void moveSubCategoryDown(String cat, String subCat) {
    List<String> list = _subCategoryOrder[cat]!;
    int idx = list.indexOf(subCat);
    if (idx != -1 && idx < list.length - 1) { list.removeAt(idx); list.insert(idx + 1, subCat); saveUserData(); notifyListeners(); }
  }

  List<Question> getQuestionsBySubCategory(String cat, String subCat) => _questions.where((q) => q.category == cat && q.subCategory == subCat).toList();

  // --- CUSTOM TEXT PARSER INTEGRATED HERE ---
  Future<bool> importQuestionsFromString(String input) async {
    try {
      final raw = input;
      String extractGlobal(String tag, String nextTag) {
        if (!raw.contains(tag)) return 'UNKNOWN';
        int start = raw.indexOf(tag) + tag.length;
        int end = raw.contains(nextTag) ? raw.indexOf(nextTag) : raw.length;
        return raw.substring(start, end).trim();
      }

      final category = extractGlobal('@@CATEGORY@@', '@@SUBCATEGORY@@');
      final subcategory = extractGlobal('@@SUBCATEGORY@@', '===BEGIN_QUESTION===');
      final blocks = raw.split('===BEGIN_QUESTION===');
      List<Question> newQs = [];

      for (int i = 1; i < blocks.length; i++) {
        var block = blocks[i];
        
        int endIdx = block.indexOf('===END_QUESTION===');
        if (endIdx != -1) block = block.substring(0, endIdx); 
        
        block = block.trim();
        if (block.isEmpty) continue;
        
        String extract(String tag, String nextTag) {
          if (!block.contains(tag)) return '';
          int start = block.indexOf(tag) + tag.length;
          int end = nextTag.isNotEmpty && block.contains(nextTag) ? block.indexOf(nextTag) : block.length;
          return block.substring(start, end).trim();
        }

        final text = extract('@@MARKDOWN@@', '@@OPT_A@@');
        final a = extract('@@OPT_A@@', '@@OPT_B@@');
        final b = extract('@@OPT_B@@', '@@OPT_C@@');
        final c = extract('@@OPT_C@@', '@@OPT_D@@');
        final d = extract('@@OPT_D@@', '@@ANSWER@@');
        final ansStr = extract('@@ANSWER@@', '').trim().toUpperCase();

        int ansIdx = 0;
        if (ansStr == 'A') ansIdx = 0;
        else if (ansStr == 'B') ansIdx = 1;
        else if (ansStr == 'C') ansIdx = 2;
        else if (ansStr == 'D') ansIdx = 3;

        if (text.isNotEmpty && ansStr.isNotEmpty) {
          newQs.add(Question(
            id: 'q_${DateTime.now().millisecondsSinceEpoch}_$i',
            category: category,
            subCategory: subcategory,
            text: text,
            options: [a, b, c, d],
            correctAnswerIndex: ansIdx
          ));
        }
      }

      if (newQs.isEmpty) return false;

      final Map<String, Question> existingMap = {for (var q in _questions) q.id: q};
      for (var q in newQs) existingMap[q.id] = q;
      _questions = existingMap.values.toList();
      
      await saveUserData(); 
      notifyListeners();
      return true;
    } catch (e) { 
      return false; 
    }
  }

  // Session / Active Test Logic
  void addSession(TestSession session) {
    _sessions.add(session);
    clearActiveState(session.category, session.subCategory);
    saveUserData(); notifyListeners();
  }
  
  TestSession? getLatestSession(String cat, String subCat) {
    try { return _sessions.lastWhere((s) => s.category == cat && s.subCategory == subCat); } catch(e) { return null; }
  }

  String _stateKey(String cat, String subCat) => "${cat}_$subCat";
  void saveActiveState(String cat, String subCat, Map<String, int> ans, Map<String, int> times, Map<String, int> statuses, int elapsed) {
    _activeStates[_stateKey(cat, subCat)] = ActiveTestState(answers: ans, times: times, statuses: statuses, totalElapsed: elapsed);
    saveUserData();
  }
  ActiveTestState? getActiveState(String cat, String subCat) => _activeStates[_stateKey(cat, subCat)];
  void clearActiveState(String cat, String subCat) { _activeStates.remove(_stateKey(cat, subCat)); saveUserData(); notifyListeners(); }
  bool isCompleted(String cat, String subCat) => _sessions.any((s) => s.category == cat && s.subCategory == subCat);

  // Manipulators (With Cascading Deletes)
  void renameCategory(String oldName, String newName) {
    for (var q in _questions) { if (q.category == oldName) q.category = newName; }
    for (var s in _sessions) { if (s.category == oldName) s.category = newName; } 
    
    Map<String, ActiveTestState> newActiveStates = {};
    _activeStates.forEach((k, v) {
      if (k.startsWith("${oldName}_")) newActiveStates["${newName}_${k.substring(oldName.length + 1)}"] = v;
      else newActiveStates[k] = v;
    });
    _activeStates = newActiveStates;

    int idx = _categoryOrder.indexOf(oldName);
    if(idx != -1) _categoryOrder[idx] = newName;
    if(_subCategoryOrder.containsKey(oldName)) _subCategoryOrder[newName] = _subCategoryOrder.remove(oldName)!;
    
    saveUserData(); notifyListeners();
  }

  void renameSubCategory(String cat, String oldSub, String newSub) {
    for (var q in _questions) { if (q.category == cat && q.subCategory == oldSub) q.subCategory = newSub; }
    for (var s in _sessions) { if (s.category == cat && s.subCategory == oldSub) s.subCategory = newSub; } 
    
    var state = _activeStates.remove(_stateKey(cat, oldSub));
    if (state != null) _activeStates[_stateKey(cat, newSub)] = state;

    int idx = _subCategoryOrder[cat]!.indexOf(oldSub);
    if(idx != -1) _subCategoryOrder[cat]![idx] = newSub;
    saveUserData(); notifyListeners();
  }

  void moveQuestion(String qId, String newCat, String newSubCat) {
    int idx = _questions.indexWhere((q) => q.id == qId);
    if (idx != -1) { _questions[idx].category = newCat; _questions[idx].subCategory = newSubCat; saveUserData(); notifyListeners(); }
  }

  void deleteCategory(String cat) { 
    _questions.removeWhere((q) => q.category == cat); 
    _sessions.removeWhere((s) => s.category == cat);
    _activeStates.removeWhere((k, v) => k.startsWith("${cat}_"));
    _categoryOrder.remove(cat);
    _subCategoryOrder.remove(cat);
    saveUserData(); notifyListeners(); 
  }

  void deleteSubCategory(String cat, String subCat) { 
    _questions.removeWhere((q) => q.category == cat && q.subCategory == subCat); 
    _sessions.removeWhere((s) => s.category == cat && s.subCategory == subCat);
    _activeStates.remove(_stateKey(cat, subCat));
    _subCategoryOrder[cat]?.remove(subCat);
    saveUserData(); notifyListeners(); 
  }

  void deleteSessionHistory(String cat, String subCat) {
    _sessions.removeWhere((s) => s.category == cat && s.subCategory == subCat);
    _activeStates.remove(_stateKey(cat, subCat));
    saveUserData(); notifyListeners();
  }

  void deleteQuestion(String id) { 
    _questions.removeWhere((q) => q.id == id); 
    saveUserData(); notifyListeners(); 
  }
}

// ==========================================
// MAIN NAVIGATION
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [HomeScreen(), OrganizeScreen(), ImportScreen(), AnalysisBaseScreen(), ProfileScreen()];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: inkBlack, width: 3))),
        child: NavigationBar(
          backgroundColor: paperBg, indicatorColor: brassAccent.withOpacity(0.5),
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.description_outlined), label: 'TESTS'),
            NavigationDestination(icon: Icon(Icons.folder_special_outlined), label: 'ORGANIZE'),
            NavigationDestination(icon: Icon(Icons.input), label: 'IMPORT'),
            NavigationDestination(icon: Icon(Icons.query_stats), label: 'GLOBAL'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.isLoading || appState.currentUser == null) return const Center(child: CircularProgressIndicator(color: Colors.black));

    int totalTests = appState.sessions.length;
    int totalQs = appState.questions.length;
    int totalAns = appState.sessions.fold(0, (s, e) => s + e.totalQuestions);
    int totalCor = appState.sessions.fold(0, (s, e) => s + e.score);
    double acc = totalAns == 0 ? 0 : (totalCor / totalAns) * 100;
    int totalTime = appState.sessions.fold(0, (s, e) => s + e.durationSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('USER_PROFILE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2), color: brassAccent.withOpacity(0.2)),
              child: Column(
                children: [
                  const Icon(Icons.person, size: 64, color: Colors.black),
                  const SizedBox(height: 8),
                  Text('ACTIVE: ${appState.currentUser!.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Divider(height: 32),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL_DB_QS:', style: TextStyle(fontWeight: FontWeight.bold)), Text('$totalQs')]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('COMPLETED_TESTS:', style: TextStyle(fontWeight: FontWeight.bold)), Text('$totalTests')]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('GLOBAL_ACCURACY:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${acc.toStringAsFixed(1)}%')]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL_TIME_SPENT:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${(totalTime / 60).toStringAsFixed(1)} MIN')]),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('REGISTERED_OPERATORS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...appState.users.map((u) => Card(
              color: u.id == appState.currentUser!.id ? steamGreen.withOpacity(0.2) : paperBg,
              child: ListTile(
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${u.id}', style: const TextStyle(fontSize: 10)),
                trailing: u.id == appState.currentUser!.id ? const Icon(Icons.check_circle, color: Colors.black) : OutlinedButton(
                  onPressed: () => appState.switchUser(u.id),
                  child: const Text('SWITCH'),
                ),
              ),
            )),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showNewUserDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text('CREATE_NEW_USER'),
            )
          ],
        ),
      ),
    );
  }

  void _showNewUserDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('NEW_OPERATOR'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'NAME')),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(onPressed: () {
            if (ctrl.text.trim().isNotEmpty) context.read<AppState>().createUser(ctrl.text.trim().toUpperCase());
            Navigator.pop(ctx);
          }, child: const Text('CREATE')),
        ],
      ),
    );
  }
}

// ==========================================
// IMPORT SCREEN (AI Prompt)
// ==========================================
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  final String aiPrompt = '''You are an expert test creator. Generate a multiple-choice test about [TOPIC]. 
You MUST strictly output the test using the exact plaintext format below. Do not use code blocks, JSON, or any conversational text.

@@CATEGORY@@
[Broad Category]
@@SUBCATEGORY@@
[Specific Topic]
===BEGIN_QUESTION===
@@MARKDOWN@@
[Question text here. Use \$ for inline math and \$\$ for block math equations.]
@@OPT_A@@
[Option A text]
@@OPT_B@@
[Option B text]
@@OPT_C@@
[Option C text]
@@OPT_D@@
[Option D text]
@@ANSWER@@
[Correct Letter: A, B, C, or D]
===END_QUESTION===''';

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('IMPORT_DATA')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2), color: brassAccent.withOpacity(0.2)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI_GENERATION_PROMPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(aiPrompt, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: aiPrompt));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('COPIED TO CLIPBOARD', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: inkBlack));
                    },
                    icon: const Icon(Icons.copy, size: 16), label: const Text('COPY TEMPLATE'),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(controller: controller, maxLines: 12, decoration: const InputDecoration(hintText: 'PASTE_RAW_DATA_HERE...', labelText: 'DATA_INPUT')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                bool success = await context.read<AppState>().importQuestionsFromString(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'SYSTEM: IMPORT SUCCESSFUL' : 'ERROR: INVALID FORMAT', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: success ? steamGreen : rustRed));
                  if(success) controller.clear();
                }
              },
              child: const Text('EXECUTE IMPORT'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HOME SCREEN (Tests)
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.getCategories();

    return Scaffold(
      appBar: AppBar(title: const Text('INDEX: DIRECTORIES')),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : categories.isEmpty
              ? const Center(child: Text('NO DATA FOUND. PROCEED TO IMPORT.', style: TextStyle(fontWeight: FontWeight.bold)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_open, color: Colors.black),
                        title: Text(category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubCategoryScreen(category: category))),
                      ),
                    );
                  },
                ),
    );
  }
}

class SubCategoryScreen extends StatelessWidget {
  final String category;
  const SubCategoryScreen({super.key, required this.category});

  void _confirmClearRecord(BuildContext context, AppState appState, String subCat) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('CLEAR_RECORD'),
      content: const Text('THIS WILL DELETE ALL ATTEMPTS AND STATS FOR THIS TEST. PROCEED?'),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: rustRed), onPressed: () {
          appState.deleteSessionHistory(category, subCat);
          Navigator.pop(ctx);
        }, child: const Text('CONFIRM')),
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    List<String> subCats = appState.getSubCategories(category);

    subCats.sort((a, b) {
      bool aComp = appState.isCompleted(category, a);
      bool bComp = appState.isCompleted(category, b);
      if (aComp == bComp) return a.compareTo(b);
      return aComp ? 1 : -1;
    });

    return Scaffold(
      appBar: AppBar(title: Text('DIR: ${category.toUpperCase()}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subCats.length,
        itemBuilder: (context, index) {
          final subCat = subCats[index];
          final questions = appState.getQuestionsBySubCategory(category, subCat);
          final isCompleted = appState.isCompleted(category, subCat);
          final hasActiveState = appState.getActiveState(category, subCat) != null;

          return Card(
            color: isCompleted ? Colors.black12 : paperBg,
            child: ListTile(
              leading: Icon(isCompleted ? Icons.check_box : Icons.insert_drive_file, color: inkBlack),
              title: Text(subCat.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, decoration: isCompleted ? TextDecoration.lineThrough : null)),
              subtitle: Text('QS: ${questions.length} | STAT: ${isCompleted ? 'COMPLETED' : (hasActiveState ? 'IN PROGRESS' : 'UNFINISHED')}'),
              trailing: isCompleted 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.analytics, color: Colors.black, size: 24),
                        tooltip: 'ANALYZE RECORD',
                        onPressed: () {
                          final session = appState.getLatestSession(category, subCat);
                          if(session != null) Navigator.push(context, MaterialPageRoute(builder: (_) => SpecificAnalysisScreen(session: session)));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.black, size: 24),
                        tooltip: 'CLEAR RECORD',
                        onPressed: () => _confirmClearRecord(context, appState, subCat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.black, size: 24),
                        tooltip: 'RETAKE TEST',
                        onPressed: () {
                          appState.clearActiveState(category, subCat);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ExamScreen(category: category, subCategory: subCat, questions: questions)));
                        },
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                    tooltip: 'EXECUTE TEST',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamScreen(category: category, subCategory: subCat, questions: questions))),
                  ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// EXAM SCREEN (Swipe via PageView)
// ==========================================
class ExamScreen extends StatefulWidget {
  final String category;
  final String subCategory;
  final List<Question> questions;
  const ExamScreen({super.key, required this.category, required this.subCategory, required this.questions});
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  final Map<String, int> _times = {};   
  final Map<String, int> _statuses = {};
  int _totalElapsed = 0;
  late Timer _timer;
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadState();
    _pageController = PageController(initialPage: _currentIndex);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _loadState() {
    final state = context.read<AppState>().getActiveState(widget.category, widget.subCategory);
    for (var q in widget.questions) { _times[q.id] = 0; _statuses[q.id] = QuestionStatus.notVisited.index; }
    if (state != null) {
      _answers.addAll(state.answers); _times.addAll(state.times); _statuses.addAll(state.statuses); _totalElapsed = state.totalElapsed;
      _currentIndex = widget.questions.indexWhere((q) => _statuses[q.id] == QuestionStatus.notVisited.index || _statuses[q.id] == QuestionStatus.notAnswered.index);
      if (_currentIndex == -1) _currentIndex = 0;
    }
    String startQId = widget.questions[_currentIndex].id;
    if (_statuses[startQId] == QuestionStatus.notVisited.index) _statuses[startQId] = QuestionStatus.notAnswered.index;
  }

  void _tick(Timer timer) {
    if(!mounted) return;
    setState(() { _totalElapsed++; String qId = widget.questions[_currentIndex].id; _times[qId] = (_times[qId] ?? 0) + 1; });
  }

  void _saveState() => context.read<AppState>().saveActiveState(widget.category, widget.subCategory, _answers, _times, _statuses, _totalElapsed);

  @override
  void dispose() { _timer.cancel(); _pageController.dispose(); super.dispose(); }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index; String nextQId = widget.questions[index].id;
      if (_statuses[nextQId] == QuestionStatus.notVisited.index) _statuses[nextQId] = QuestionStatus.notAnswered.index;
    });
    _saveState();
  }

  void _goToIndex(int index) => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  void _updateStatusAndNext(QuestionStatus newStatus) {
    setState(() { _statuses[widget.questions[_currentIndex].id] = newStatus.index; });
    if (_currentIndex < widget.questions.length - 1) _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    else _saveState();
  }

  void _submitTest() {
    _timer.cancel(); int score = 0;
    for (var q in widget.questions) { if (_answers[q.id] == q.correctAnswerIndex) score++; }
    final session = TestSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: widget.category, subCategory: widget.subCategory, score: score, totalQuestions: widget.questions.length,
      durationSeconds: _totalElapsed, timestamp: DateTime.now().millisecondsSinceEpoch,
      questions: widget.questions, userAnswers: _answers, timePerQuestion: _times,
    );
    context.read<AppState>().addSession(session);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(session: session)));
  }

  Color _getStatusColor(int statusIdx) {
    if (statusIdx == QuestionStatus.notVisited.index) return Colors.grey.shade400;
    if (statusIdx == QuestionStatus.notAnswered.index) return rustRed;
    if (statusIdx == QuestionStatus.answered.index) return steamGreen;
    return Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    final int minutes = _totalElapsed ~/ 60; final int seconds = _totalElapsed % 60;

    return WillPopScope(
      onWillPop: () async { _saveState(); return true; },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("T:${minutes.toString().padLeft(2,'0')}:${seconds.toString().padLeft(2,'0')} | Q:${_times[widget.questions[_currentIndex].id]}s"),
          actions: [IconButton(icon: const Icon(Icons.grid_view, color: Colors.black), onPressed: () => _scaffoldKey.currentState?.openEndDrawer())],
        ),
        endDrawer: Drawer(
          child: Column(children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))), child: const Text('PALETTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            Expanded(child: GridView.builder(
              padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: widget.questions.length,
              itemBuilder: (ctx, i) {
                int sIdx = _statuses[widget.questions[i].id] ?? 0;
                return GestureDetector(
                  onTap: () { Navigator.pop(context); _goToIndex(i); },
                  child: Container(
                    decoration: BoxDecoration(color: _getStatusColor(sIdx), border: Border.all(color: _currentIndex == i ? Colors.white : inkBlack, width: _currentIndex == i ? 3 : 2)),
                    alignment: Alignment.center, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            )),
          ]),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(value: (_currentIndex + 1) / widget.questions.length, backgroundColor: paperBg, color: inkBlack, minHeight: 4),
            Expanded(child: PageView.builder(
              controller: _pageController, onPageChanged: _onPageChanged, itemCount: widget.questions.length,
              itemBuilder: (context, idx) {
                final question = widget.questions[idx]; final qId = question.id;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('ID: $qId [${idx + 1}/${widget.questions.length}]', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    const Divider(height: 32),
                    // CUSTOM PARSER INJECTED HERE
                    BrutalistMarkdown(data: question.text),
                    const SizedBox(height: 32),
                    ...List.generate(question.options.length, (optIdx) {
                      bool isSelected = _answers[qId] == optIdx;
                      String optionLetter = String.fromCharCode(65 + optIdx); // A, B, C, D
                      return InkWell(
                        onTap: () { setState(() => _answers[qId] = optIdx); _saveState(); },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isSelected ? brassAccent.withOpacity(0.3) : paperBg, border: Border.all(color: inkBlack, width: isSelected ? 3 : 2)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Radio<int>(value: optIdx, groupValue: _answers[qId], activeColor: inkBlack, onChanged: (v) { setState(() => _answers[qId] = v!); _saveState(); }), 
                            Text('$optionLetter. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            // CUSTOM PARSER INJECTED HERE
                            Expanded(child: BrutalistMarkdown(data: question.options[optIdx]))
                          ]),
                        ),
                      );
                    }),
                  ],
                );
              },
            )),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: inkBlack, width: 3)), color: paperBg), padding: const EdgeInsets.all(8),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  OutlinedButton(onPressed: () { final qId = widget.questions[_currentIndex].id; setState(() { _answers.remove(qId); _statuses[qId] = QuestionStatus.notAnswered.index; }); _saveState(); }, child: const Text('CLEAR')),
                  OutlinedButton(onPressed: () { final qId = widget.questions[_currentIndex].id; _updateStatusAndNext(_answers.containsKey(qId) ? QuestionStatus.answeredAndMarked : QuestionStatus.markedForReview); }, child: const Text('MARK & NEXT')),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  if (_currentIndex > 0) FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade700), onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('PREV')),
                  if (_currentIndex < widget.questions.length - 1) FilledButton(onPressed: () { final qId = widget.questions[_currentIndex].id; _updateStatusAndNext(_answers.containsKey(qId) ? QuestionStatus.answered : QuestionStatus.notAnswered); }, child: const Text('SAVE & NEXT'))
                  else FilledButton(style: FilledButton.styleFrom(backgroundColor: steamGreen), onPressed: _submitTest, child: const Text('SUBMIT TEST')),
                ])
              ]),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// RESULT & SPECIFIC ANALYSIS SCREENS
// ==========================================
class ResultScreen extends StatelessWidget {
  final TestSession session;
  const ResultScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    double perc = session.totalQuestions > 0 ? (session.score / session.totalQuestions) * 100 : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('EVALUATION_REPORT'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('STATUS: ${perc >= 70 ? 'PASS' : 'FAIL'}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: perc >= 70 ? steamGreen : rustRed)),
              const Divider(height: 48),
              Text('SCORE: ${session.score} / ${session.totalQuestions}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('ACCURACY: ${perc.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20)),
              Text('TIME: ${session.durationSeconds}s', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 48),
              FilledButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SpecificAnalysisScreen(session: session))), child: const Text('INITIATE REVIEW')),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('TERMINATE')),
            ],
          ),
        ),
      ),
    );
  }
}

class SpecificAnalysisScreen extends StatefulWidget {
  final TestSession session;
  const SpecificAnalysisScreen({super.key, required this.session});
  @override
  State<SpecificAnalysisScreen> createState() => _SpecificAnalysisScreenState();
}

class _SpecificAnalysisScreenState extends State<SpecificAnalysisScreen> {
  SortMode _sortMode = SortMode.defaultOrder;

  @override
  Widget build(BuildContext context) {
    List<Question> sortedQs = List.from(widget.session.questions);
    sortedQs.sort((a, b) {
      if (_sortMode == SortMode.timeAsc) return (widget.session.timePerQuestion[a.id] ?? 0).compareTo(widget.session.timePerQuestion[b.id] ?? 0);
      else if (_sortMode == SortMode.timeDesc) return (widget.session.timePerQuestion[b.id] ?? 0).compareTo(widget.session.timePerQuestion[a.id] ?? 0);
      else {
        bool aCor = widget.session.userAnswers[a.id] == a.correctAnswerIndex; bool bCor = widget.session.userAnswers[b.id] == b.correctAnswerIndex;
        bool aAns = widget.session.userAnswers.containsKey(a.id); bool bAns = widget.session.userAnswers.containsKey(b.id);
        int score(bool isCor, bool isAns) => isCor ? 2 : (!isAns ? 1 : 0);
        return score(aCor, aAns).compareTo(score(bCor, bAns));
      }
    });

    double perc = widget.session.totalQuestions > 0 ? (widget.session.score / widget.session.totalQuestions) * 100 : 0;
    double avgTime = widget.session.totalQuestions > 0 ? (widget.session.durationSeconds / widget.session.totalQuestions) : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('SPECIFIC_ANALYSIS_MATRIX')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 3)), color: brassAccent.withOpacity(0.1)),
              child: Column(children: [
                Text('TEST: ${widget.session.subCategory}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('SCORE:'), Text('${widget.session.score}/${widget.session.totalQuestions}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('ACCURACY:'), Text('${perc.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('AVG_TIME/Q:'), Text('${avgTime.toStringAsFixed(1)}s', style: const TextStyle(fontWeight: FontWeight.bold))]),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('SORT_OPTS:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<SortMode>(
                  value: _sortMode, dropdownColor: paperBg, underline: const SizedBox(),
                  style: TextStyle(fontFamily: 'Courier', color: inkBlack, fontWeight: FontWeight.bold),
                  items: const [DropdownMenuItem(value: SortMode.defaultOrder, child: Text('ERRORS_FIRST')), DropdownMenuItem(value: SortMode.timeAsc, child: Text('TIME_ASC (FAST)')), DropdownMenuItem(value: SortMode.timeDesc, child: Text('TIME_DESC (SLOW)'))],
                  onChanged: (v) => setState(() => _sortMode = v!),
                )
              ]),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final q = sortedQs[i]; final uAns = widget.session.userAnswers[q.id];
              final isCorrect = uAns == q.correctAnswerIndex; final timeS = widget.session.timePerQuestion[q.id] ?? 0;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(isCorrect ? '[VALID]' : (uAns == null ? '[NULL]' : '[ERROR]'), style: TextStyle(color: isCorrect ? steamGreen : rustRed, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('TIME: ${timeS}s', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    const Divider(height: 24), 
                    // CUSTOM PARSER INJECTED HERE
                    BrutalistMarkdown(data: q.text), 
                    const SizedBox(height: 16),
                    ...List.generate(q.options.length, (optIdx) {
                      bool correctOpt = optIdx == q.correctAnswerIndex; bool selectedOpt = optIdx == uAns;
                      Color bg = paperBg; if (correctOpt) bg = steamGreen.withOpacity(0.3); else if (selectedOpt && !correctOpt) bg = rustRed.withOpacity(0.3);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: bg, border: Border.all(color: inkBlack, width: correctOpt || selectedOpt ? 2 : 1)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (correctOpt) const Icon(Icons.check, color: Colors.black) else if (selectedOpt) const Icon(Icons.close, color: Colors.black) else const SizedBox(width: 24),
                          const SizedBox(width: 8), 
                          // CUSTOM PARSER INJECTED HERE
                          Expanded(child: BrutalistMarkdown(data: q.options[optIdx])),
                        ]),
                      );
                    })
                  ]),
                ),
              );
            }, childCount: sortedQs.length),
          )
        ],
      ),
    );
  }
}

// ==========================================
// GLOBAL ANALYSIS (Tabs: Stats & Records)
// ==========================================
class AnalysisBaseScreen extends StatelessWidget {
  const AnalysisBaseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GLOBAL_ANALYSIS'),
          bottom: TabBar(
            indicator: BoxDecoration(color: inkBlack), labelColor: paperBg, unselectedLabelColor: inkBlack,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier'),
            tabs: const [Tab(text: 'STATS'), Tab(text: 'RECORDS')],
          ),
        ),
        body: const TabBarView(children: [GlobalStatsTab(), GlobalRecordsTab()]),
      ),
    );
  }
}

class GlobalStatsTab extends StatelessWidget {
  const GlobalStatsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().sessions;
    if (sessions.isEmpty) return const Center(child: Text('NO DATA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)));

    Map<String, List<TestSession>> sessionsByCategory = {};
    for (var s in sessions) sessionsByCategory.putIfAbsent(s.category, () => []).add(s);

    List<BarChartGroupData> barGroups = []; List<String> categoryLabels = []; List<Map<String, dynamic>> categoryStats = []; int xIndex = 0;
    sessionsByCategory.forEach((cat, list) {
      int totalQ = list.fold(0, (sum, s) => sum + s.totalQuestions);
      int totalScore = list.fold(0, (sum, s) => sum + s.score);
      int totalTime = list.fold(0, (sum, s) => sum + s.durationSeconds);
      double accuracy = totalQ > 0 ? (totalScore / totalQ) * 100 : 0;
      double avgTime = totalQ > 0 ? (totalTime / totalQ) : 0;
      barGroups.add(BarChartGroupData(x: xIndex++, barRods: [BarChartRodData(toY: accuracy, color: inkBlack, width: 24, borderRadius: BorderRadius.zero)]));
      categoryLabels.add(cat); categoryStats.add({'cat': cat, 'acc': accuracy, 'avgTime': avgTime});
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ACCURACY_GRAPH [%]', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 24),
        Container(
          height: 250, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2)),
          child: BarChart(BarChartData(
            maxY: 100,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(categoryLabels[val.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text('${val.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.black26, strokeWidth: 1, dashArray: [4, 4])), borderData: FlBorderData(show: false), barGroups: barGroups,
          )),
        ),
        const SizedBox(height: 32), const Text('CATEGORY_BREAKDOWN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        ...categoryStats.map((stat) => Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stat['cat'].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('ACCURACY: ${(stat['acc'] as double).toStringAsFixed(1)}%'), Text('AVG TIME/Q: ${(stat['avgTime'] as double).toStringAsFixed(1)}s')])
        ]))))
      ]),
    );
  }
}

class GlobalRecordsTab extends StatefulWidget {
  const GlobalRecordsTab({super.key});
  @override
  State<GlobalRecordsTab> createState() => _GlobalRecordsTabState();
}

class _GlobalRecordsTabState extends State<GlobalRecordsTab> {
  SortMode _sortMode = SortMode.timeDesc;
  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().sessions;
    if (sessions.isEmpty) return const Center(child: Text('NO DATA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)));

    List<Map<String, dynamic>> allRecords = [];
    for (var s in sessions) {
      for (var q in s.questions) {
        int time = s.timePerQuestion[q.id] ?? 0; bool isCorrect = s.userAnswers[q.id] == q.correctAnswerIndex; bool isAns = s.userAnswers.containsKey(q.id);
        allRecords.add({'q': q, 'time': time, 'isCorrect': isCorrect, 'isAns': isAns, 'sessionCat': s.category});
      }
    }
    allRecords.sort((a, b) {
      if (_sortMode == SortMode.timeAsc) return (a['time'] as int).compareTo(b['time'] as int);
      if (_sortMode == SortMode.timeDesc) return (b['time'] as int).compareTo(a['time'] as int);
      return (a['isCorrect'] ? 2 : (!a['isAns'] ? 1 : 0)).compareTo(b['isCorrect'] ? 2 : (!b['isAns'] ? 1 : 0));
    });

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: inkBlack, width: 2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('SORT_ALL_QS:', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<SortMode>(
            value: _sortMode, dropdownColor: paperBg, underline: const SizedBox(), style: TextStyle(fontFamily: 'Courier', color: inkBlack, fontWeight: FontWeight.bold),
            items: const [DropdownMenuItem(value: SortMode.defaultOrder, child: Text('ERRORS_FIRST')), DropdownMenuItem(value: SortMode.timeAsc, child: Text('FASTEST_FIRST')), DropdownMenuItem(value: SortMode.timeDesc, child: Text('SLOWEST_FIRST'))],
            onChanged: (v) => setState(() => _sortMode = v!),
          )
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: allRecords.length,
        itemBuilder: (ctx, i) {
          final rec = allRecords[i]; final Question q = rec['q'];
          return Card(child: ListTile(
            leading: Text('${rec['time']}s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('DIR: ${rec['sessionCat']}'),
            trailing: Icon(rec['isCorrect'] ? Icons.check_box : Icons.cancel_presentation, color: rec['isCorrect'] ? steamGreen : rustRed),
          ));
        },
      ))
    ]);
  }
}

// ==========================================
// ORGANIZE SCREEN (Drag & Drop Reordering)
// ==========================================
class OrganizeScreen extends StatelessWidget {
  const OrganizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.getCategories();

    return Scaffold(
      appBar: AppBar(title: const Text('SYS_ORGANIZATION')),
      body: categories.isEmpty
          ? const Center(child: Text('EMPTY_DATABASE', style: TextStyle(fontWeight: FontWeight.bold)))
          : ReorderableListView.builder(
              itemCount: categories.length,
              onReorder: (oldIdx, newIdx) => appState.reorderCategory(oldIdx, newIdx),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Container(
                  key: ValueKey(cat),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(border: Border.all(color: inkBlack, width: 2), color: paperBg),
                  child: ExpansionTile(
                    leading: const Icon(Icons.drag_indicator, color: Colors.black),
                    title: Row(children: [
                      Text(cat.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _renameCatDialog(context, cat)),
                    ]),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.black), onPressed: () => appState.deleteCategory(cat)),
                    children: appState.getSubCategories(cat).map((subCat) {
                      return Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: inkBlack, width: 2)), color: brassAccent.withOpacity(0.1)),
                        child: ExpansionTile(
                          title: Row(children: [
                            Column(children: [
                              InkWell(child: const Icon(Icons.keyboard_arrow_up), onTap: () => appState.moveSubCategoryUp(cat, subCat)),
                              InkWell(child: const Icon(Icons.keyboard_arrow_down), onTap: () => appState.moveSubCategoryDown(cat, subCat)),
                            ]),
                            const SizedBox(width: 8),
                            Text('> ${subCat.toUpperCase()}'),
                            const Spacer(),
                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _renameSubCatDialog(context, cat, subCat)),
                          ]),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.black), onPressed: () => appState.deleteSubCategory(cat, subCat)),
                          children: appState.getQuestionsBySubCategory(cat, subCat).map((q) => ListTile(
                            title: Text(q.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.drive_file_move_outline, size: 20, color: Colors.black), onPressed: () => _moveQuestionDialog(context, q)),
                              IconButton(icon: const Icon(Icons.delete_forever, size: 20, color: Colors.black), onPressed: () => appState.deleteQuestion(q.id)),
                            ]),
                          )).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  void _renameCatDialog(BuildContext context, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('RENAME_DIR'), content: TextField(controller: ctrl),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () { if(ctrl.text.trim().isNotEmpty) context.read<AppState>().renameCategory(oldName, ctrl.text.trim()); Navigator.pop(ctx); }, child: const Text('CONFIRM')),
      ]
    ));
  }
  void _renameSubCatDialog(BuildContext context, String cat, String oldSub) {
    final ctrl = TextEditingController(text: oldSub);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('RENAME_SUB_DIR'), content: TextField(controller: ctrl),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () { if(ctrl.text.trim().isNotEmpty) context.read<AppState>().renameSubCategory(cat, oldSub, ctrl.text.trim()); Navigator.pop(ctx); }, child: const Text('CONFIRM')),
      ]
    ));
  }
  void _moveQuestionDialog(BuildContext context, Question q) {
    final catCtrl = TextEditingController(text: q.category); final subCtrl = TextEditingController(text: q.subCategory);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('MOVE_FILE'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'DEST_DIR')), const SizedBox(height: 16), TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'DEST_SUB_DIR'))]),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        FilledButton(onPressed: () { if(catCtrl.text.trim().isNotEmpty && subCtrl.text.trim().isNotEmpty) context.read<AppState>().moveQuestion(q.id, catCtrl.text.trim(), subCtrl.text.trim()); Navigator.pop(ctx); }, child: const Text('EXECUTE')),
      ]
    ));
  }
}
