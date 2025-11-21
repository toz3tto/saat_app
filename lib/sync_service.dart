import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'db_helper.dart';
import 'main.dart';

/// Serviço de sincronização entre o SQLite local e o Supabase.
class SyncService {
  static Future<List<Map<String, dynamic>>> sincronizar() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('⛔ Sem internet. Não foi possível sincronizar.');
      return [];
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      print('⚠️ Nenhum usuário logado.');
      return [];
    }

    print('🔄 Iniciando sincronização para o usuário: ${user.email} (${user.id})');

    try {
      // 1. Busca os chamados do Supabase filtrados por usuário
      final response = await supabase
          .from('saat_chamados')
          .select()
          .eq('usuario_id', user.id)
          .order('id', ascending: false);

      final chamadosSupabase = List<Map<String, dynamic>>.from(response);

      print('📥 ${chamadosSupabase.length} chamados encontrados no Supabase.');

      // 2. Se for Web, não usa SQLite — apenas retorna os dados
      if (kIsWeb) {
        print('🌐 Modo Web detectado — usando dados diretos do Supabase.');
        return chamadosSupabase;
      }

      // 3. Mobile/Desktop → sincroniza com SQLite local
      await DBHelper.inserirChamados(chamadosSupabase);

      // 4. Envia alterações locais pendentes (somente status por enquanto)
      final naoSync = await DBHelper.listarNaoSincronizados();
      for (final c in naoSync) {
        await supabase
            .from('saat_chamados')
            .update({
              'status_chamado': c['status_chamado'],
            })
            .eq('id', c['id']);

        await DBHelper.marcarComoSincronizado(c['id']);
      }

      print('✅ Sincronização concluída com sucesso.');
      return chamadosSupabase;
    } catch (e) {
      print('🚨 Erro durante a sincronização: $e');
      return [];
    }
  }
}
