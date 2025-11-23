import 'dart:io';
import 'dart:convert';
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
      databaseFactory = databaseFactoryFfiWeb;
      _db = await databaseFactory.openDatabase('saat_web.db');
      await _criarTabela(_db!);
      print('🌐 Banco Web inicializado com sqflite_common_ffi_web.');
      return _db!;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'saat_desktop.db');
      _db = await databaseFactory.openDatabase(path);
      await _criarTabela(_db!);
      print('🖥️ Banco SQLite inicializado (Desktop).');
      return _db!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'saat_local.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _criarTabela(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _criarTabela(db);
        }
      },
    );

    print('📱 Banco SQLite inicializado (${Platform.operatingSystem}).');
    return _db!;
  }

  static Future<void> _criarTabela(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chamados (
        id INTEGER PRIMARY KEY,
        solicitante TEXT,
        telefone TEXT,
        email TEXT,
        cidade TEXT,
        estado TEXT,
        endereco TEXT,
        cep TEXT,
        bairro TEXT,
        numero TEXT,
        complemento TEXT,
        equipamento TEXT,
        problema_relatado TEXT,
        tipo_solicitante TEXT,
        status_chamado TEXT,
        nome_cliente TEXT,
        cpf_cnpj_cliente TEXT,
        nome_completo TEXT,
        matricula TEXT,
        tecnico_responsavel TEXT,
        data_visita TEXT,
        observacoes_internas TEXT,
        fotos TEXT,
        usuario_id TEXT,
        created_at TEXT,
        sincronizado INTEGER DEFAULT 1
      )
    ''');
  }

  /// Insere/atualiza a lista de chamados vinda do Supabase
  static Future<void> inserirChamados(
      List<Map<String, dynamic>> chamados) async {
    final db = await database;

    for (final c in chamados) {
      final local = <String, dynamic>{
        'id': c['id'],
        'solicitante': c['solicitante'],
        'telefone': c['telefone'],
        'email': c['email'],
        'cidade': c['cidade'],
        'estado': c['estado'],
        'endereco': c['endereco'],
        'cep': c['cep'],
        'bairro': c['bairro'],
        'numero': c['numero'],
        'complemento': c['complemento'],
        'equipamento': c['equipamento'],
        'problema_relatado': c['problema_relatado'],
        'tipo_solicitante': c['tipo_solicitante'],
        'status_chamado': c['status_chamado'],
        'nome_cliente': c['nome_cliente'],
        'cpf_cnpj_cliente': c['cpf_cnpj_cliente'],
        'nome_completo': c['nome_completo'],
        'matricula': c['matricula'],
        'tecnico_responsavel': c['tecnico_responsavel'],
        'data_visita': c['data_visita'],
        'observacoes_internas': c['observacoes_internas'],
        'usuario_id': c['usuario_id'],
        'created_at': c['created_at'],
        'fotos': c['fotos'] != null ? jsonEncode(c['fotos']) : null,
        'sincronizado': 1,
      };

      await db.insert(
        'chamados',
        local,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> listarChamados() async {
    final db = await database;
    return db.query('chamados', orderBy: 'id ASC');
  }

  static Future<void> atualizarStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'chamados',
      {
        'status_chamado': status,
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<Map<String, dynamic>>> listarNaoSincronizados() async {
    final db = await database;
    return db.query('chamados', where: 'sincronizado = 0');
  }

  static Future<void> marcarComoSincronizado(int id) async {
    final db = await database;
    await db.update(
      'chamados',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
