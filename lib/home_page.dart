import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'sync_service.dart';
import 'login_page.dart';
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
    await SyncService.sincronizar();
    final lista = await DBHelper.listarChamados();
    setState(() {
      chamados = lista;
      carregando = false;
    });
  }

  Future<void> atualizarStatus(int id, String novoStatus) async {
    await DBHelper.atualizarStatus(id, novoStatus);
    await carregarChamados();
    await SyncService.sincronizar();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
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
        onPressed: () => Navigator.pushNamed(context, '/form'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Chamado'),
        backgroundColor: const Color(0xFF004AAD),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: carregarChamados,
              child: chamados.isEmpty
                  ? const Center(child: Text('Nenhum chamado disponível.'))
                  : ListView.builder(
                      itemCount: chamados.length,
                      itemBuilder: (context, i) {
                        final c = chamados[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: ListTile(
                            title: Text(c['equipamento'] ?? 'Sem equipamento'),
                            subtitle: Text(
                              '${c['problema_relatado'] ?? c['problema'] ?? ''}\nCidade: ${c['cidade'] ?? '-'}',
                            ),
                            trailing: DropdownButton<String>(
                              value: c['status_chamado'] ??
                                  c['status'] ??
                                  'Pendente',
                              onChanged: (valor) async {
                                if (valor != null) {
                                  await atualizarStatus(c['id'], valor);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                    value: 'Pendente',
                                    child: Text('Pendente')),
                                DropdownMenuItem(
                                    value: 'Em atendimento',
                                    child: Text('Em atendimento')),
                                DropdownMenuItem(
                                    value: 'Finalizado',
                                    child: Text('Finalizado')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
