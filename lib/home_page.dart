import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'db_helper.dart';
import 'sync_service.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> chamados = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    carregarChamados();
  }

  Future<void> carregarChamados() async {
    setState(() => carregando = true);

    try {
      if (kIsWeb) {
        final response = await supabase
            .from('saat_chamados')
            .select()
            .order('id', ascending: false);

        chamados = List<Map<String, dynamic>>.from(response);
      } else {
        await SyncService.sincronizar();
        chamados = await DBHelper.listarChamados();
      }

      if (mounted) {
        setState(() => carregando = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar chamados: $e")),
        );
      }
    }
  }

  Future<void> atualizarStatus(int id, String novoStatus) async {
    if (kIsWeb) {
      await supabase
          .from('saat_chamados')
          .update({'status_chamado': novoStatus})
          .eq('id', id);
    } else {
      await DBHelper.atualizarStatus(id, novoStatus);
      await SyncService.sincronizar();
    }

    carregarChamados();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Color _corStatus(String? status) {
    switch (status) {
      case 'Finalizado':
        return Colors.green;
      case 'Em atendimento':
        return Colors.orange;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chamados SAAT'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF004AAD),
        icon: const Icon(Icons.add),
        label: const Text('Novo Chamado'),
        onPressed: () => Navigator.pushNamed(context, '/form'),
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: carregarChamados,
              child: chamados.isEmpty
                  ? const Center(child: Text("Nenhum chamado disponível."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chamados.length,
                      itemBuilder: (context, index) {
                        final c = chamados[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // Número do Chamado + Status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Chamado #${c['id']}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF004AAD),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _corStatus(
                                            c['status_chamado'] ?? 'Pendente'),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        c['status_chamado'] ?? 'Pendente',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Nome do Cliente
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline,
                                        size: 20, color: Colors.black54),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        c['nome_cliente'] ??
                                            'Cliente não informado',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // Cidade
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 20, color: Colors.red),
                                    const SizedBox(width: 6),
                                    Text(
                                      c['cidade'] ?? '-',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // Equipamento
