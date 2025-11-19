import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Classe responsável por gerenciar o banco local de forma compatível com todas as plataformas.
class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    if (kIsWeb) {
      // ✅ Usa o banco compatível com Web
      databaseFactory = databaseFactoryFfiWeb;
      _db = await databaseFactory.openDatabase('saat_web.db');
      await _criarTabela(_db!);
      print('🌐 Banco Web inicializado com sqflite_common_ffi_web.');
      return _db!;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // ✅ Desktop (usa FFI normal)
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'saat_desktop.db');
      _db = await databaseFactory.openDatabase(path);
      await _criarTabela(_db!);
      print('🖥️ Banco SQLite inicializado (Desktop).');
      return _db!;
    }

    // ✅ Mobile (Android/iOS)
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'saat_local.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await _criarTabela(db);
    });

    print('📱 Banco SQLite inicializado (${Platform.operatingSystem}).');
    return _db!;
  }

  static Future<void> _criarTabela(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chamados (
        id INTEGER PRIMARY KEY,
        solicitante TEXT,
        cidade TEXT,
        equipamento TEXT,
        problema TEXT,
        status TEXT,
        sincronizado INTEGER DEFAULT 1
      )
    ''');
  }

  static Future<void> inserirChamados(List<Map<String, dynamic>> chamados) async {
    final db = await database;
    for (final c in chamados) {
      await db.insert('chamados', c, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<List<Map<String, dynamic>>> listarChamados() async {
    final db = await database;
    return db.query('chamados', orderBy: 'id DESC');
  }

  static Future<void> atualizarStatus(int id, String status) async {
    final db = await database;
    await db.update('chamados', {'status': status, 'sincronizado': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> listarNaoSincronizados() async {
    final db = await database;
    return db.query('chamados', where: 'sincronizado = 0');
  }

  static Future<void> marcarComoSincronizado(int id) async {
    final db = await database;
    await db.update('chamados', {'sincronizado': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
