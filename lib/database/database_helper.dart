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
      version: 1,
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
} 