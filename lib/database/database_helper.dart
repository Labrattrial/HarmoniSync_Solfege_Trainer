import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'practice.db');
    return await openDatabase(
      path,
      version: 2, // Increment version for new table
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exercises (
            exercises_id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            type TEXT,
            difficulty TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE performances (
            performances_id INTEGER PRIMARY KEY AUTOINCREMENT,
            exercises_id INTEGER,
            score REAL,
            attempt_time TEXT,
            recording_path TEXT,
            FOREIGN KEY (exercises_id) REFERENCES exercises (exercises_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE practice_sessions (
            session_id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            score INTEGER NOT NULL,
            total_notes INTEGER NOT NULL,
            percentage REAL NOT NULL,
            practice_date TEXT NOT NULL,
            practice_time TEXT NOT NULL,
            duration_seconds REAL NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add practice_sessions table for existing databases
          await db.execute('''
            CREATE TABLE practice_sessions (
              session_id INTEGER PRIMARY KEY AUTOINCREMENT,
              level TEXT NOT NULL,
              score INTEGER NOT NULL,
              total_notes INTEGER NOT NULL,
              percentage REAL NOT NULL,
              practice_date TEXT NOT NULL,
              practice_time TEXT NOT NULL,
              duration_seconds REAL NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // Insert Exercise
  Future<int> insertExercise(Map<String, dynamic> exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise);
  }

  // Insert Performance
  Future<int> insertPerformance(Map<String, dynamic> performance) async {
    final db = await database;
    return await db.insert('performances', performance);
  }

  // Insert Practice Session
  Future<int> insertPracticeSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.insert('practice_sessions', session);
  }

  // Get all performances for an exercise
  Future<List<Map<String, dynamic>>> getPerformances(int exercisesId) async {
    final db = await database;
    return await db.query(
      'performances',
      where: 'exercises_id = ?',
      whereArgs: [exercisesId],
      orderBy: 'attempt_time DESC',
    );
  }

  // Get all exercises
  Future<List<Map<String, dynamic>>> getExercises() async {
    final db = await database;
    return await db.query('exercises', orderBy: 'created_at DESC');
  }

  // Get all practice sessions
  Future<List<Map<String, dynamic>>> getPracticeSessions() async {
    final db = await database;
    return await db.query(
      'practice_sessions',
      orderBy: 'created_at DESC',
    );
  }

  // Get practice sessions by level
  Future<List<Map<String, dynamic>>> getPracticeSessionsByLevel(String level) async {
    final db = await database;
    return await db.query(
      'practice_sessions',
      where: 'level = ?',
      whereArgs: [level],
      orderBy: 'created_at DESC',
    );
  }

  // Get practice statistics
  Future<Map<String, dynamic>> getPracticeStatistics() async {
    final db = await database;
    
    // Get total sessions
    final totalSessions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM practice_sessions')
    ) ?? 0;
    
    // Get average score
    final avgScoreResult = await db.rawQuery('SELECT AVG(percentage) FROM practice_sessions');
    final avgScore = avgScoreResult.isNotEmpty && avgScoreResult.first.values.first != null
        ? (avgScoreResult.first.values.first as num).toDouble()
        : 0.0;
    
    // Get best score
    final bestScoreResult = await db.rawQuery('SELECT MAX(percentage) FROM practice_sessions');
    final bestScore = bestScoreResult.isNotEmpty && bestScoreResult.first.values.first != null
        ? (bestScoreResult.first.values.first as num).toDouble()
        : 0.0;
    
    // Get total practice time
    final totalTimeResult = await db.rawQuery('SELECT SUM(duration_seconds) FROM practice_sessions');
    final totalTime = totalTimeResult.isNotEmpty && totalTimeResult.first.values.first != null
        ? (totalTimeResult.first.values.first as num).toDouble()
        : 0.0;
    
    return {
      'totalSessions': totalSessions,
      'averageScore': avgScore,
      'bestScore': bestScore,
      'totalPracticeTime': totalTime,
    };
  }

  // Clear all practice sessions (for testing purposes)
  Future<void> clearAllPracticeSessions() async {
    final db = await database;
    await db.delete('practice_sessions');
  }
} 