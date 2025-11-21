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
  bool isGestor = false;

  @override
  void initState() {
    super.initState();
    _carregarPerfilEChamados();
  }

  Future<void> _carregarPerfilEChamados() async {
    await _carregarRole();
    await carregarChamados();
  }

  Future<void> _carregarRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      setState(() {
        isGestor = (data['role'] == 'gestor');
      });
    } catch (_) {
      setState(() => isGestor = false);
    }
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
        setState(() => carregando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Future<void> atualizarStatus(int id, String novoStatus) async {
    if (!isGestor) return;

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

  Future<void> _editarChamado(Map<String, dynamic> chamado) async {
    if (!isGestor) return;

    final tecnicoController =
        TextEditingController(text: chamado['tecnico_responsavel'] ?? '');

    final observacoesController =
        TextEditingController(text: chamado['observacoes_internas'] ?? '');

    DateTime? dataVisita;
    if (chamado['data_visita'] != null) {
      try {
        dataVisita = DateTime.parse(chamado['data_visita']);
      } catch (_) {}
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: Text("Editar Chamado #${chamado['id']}"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: tecnicoController,
                      decoration: const InputDecoration(
                        labelText: "Técnico responsável",
                        prefixIcon: Icon(Icons.engineering),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Data da visita",
                        prefixIcon: const Icon(Icons.calendar_today),
                        hintText: dataVisita != null
                            ? "${dataVisita?.day.toString().padLeft(2, '0')}/"
                                "${dataVisita?.month.toString().padLeft(2, '0')}/"
                                "${dataVisita?.year}"
                            : "Selecionar data",
                      ),
                      onTap: () async {
                        final selecionada = await showDatePicker(
                          context: context,
                          initialDate: dataVisita ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (selecionada != null) {
                          setDialog(() => dataVisita = selecionada);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: observacoesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Observações internas",
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar")),
                ElevatedButton(
                    onPressed: () async {
                      final update = {
                        'tecnico_responsavel': tecnicoController.text,
                        'observacoes_internas': observacoesController.text,
                        'data_visita': dataVisita?.toIso8601String(),
                      };

                      await supabase
                          .from('saat_chamados')
                          .update(update)
                          .eq('id', chamado['id']);

                      if (!kIsWeb) {
                        await SyncService.sincronizar();
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        carregarChamados();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Chamado atualizado!")));
                      }
                    },
                    child: const Text("Salvar")),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');
  }

  Color _corStatus(String status) {
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
        title: Text(isGestor ? "Painel do Gestor" : "Chamados SAAT"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF004AAD),
        label: const Text("Novo Chamado"),
        icon: const Icon(Icons.add),
        onPressed: () => Navigator.pushNamed(context, '/form'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chamados.length,
              itemBuilder: (context, i) {
                final c = chamados[i];

                final status = c['status_chamado'] ?? 'Pendente';
                final tecnico = c['tecnico_responsavel'] ?? 'Não definido';

                // data_visita formatada
                String dataVisitaStr = "Não definida";
                if (c['data_visita'] != null) {
                  try {
                    final dv = DateTime.parse(c['data_visita']);
                    dataVisitaStr =
                        "${dv.day.toString().padLeft(2, '0')}/"
                        "${dv.month.toString().padLeft(2, '0')}/"
                        "${dv.year}";
                  } catch (_) {}
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Topo: número + status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Chamado #${c['id']}",
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004AAD)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _corStatus(status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 12),

                      _linha(Icons.person, "Cliente:", c['nome_cliente']),
                      _linha(Icons.location_on, "Cidade:", c['cidade']),
                      _linha(Icons.settings, "Equipamento:", c['equipamento']),
                      _linha(Icons.engineering, "Técnico:", tecnico),
                      _linha(Icons.calendar_month, "Visita:", dataVisitaStr),

                      const SizedBox(height: 20),

                      if (isGestor) ...[
                        const Text("Status:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        DropdownButton<String>(
                          value: status,
                          isExpanded: true,
                          onChanged: (v) =>
                              atualizarStatus(c['id'], v ?? status),
                          items: const [
                            DropdownMenuItem(
                                value: "Pendente", child: Text("Pendente")),
                            DropdownMenuItem(
                                value: "Em atendimento",
                                child: Text("Em atendimento")),
                            DropdownMenuItem(
                                value: "Finalizado", child: Text("Finalizado")),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _editarChamado(c),
                          icon: const Icon(Icons.edit),
                          label: const Text("Editar técnico / visita"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004AAD)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _linha(IconData icone, String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icone, size: 20, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            "$label ",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Expanded(
            child: Text(
              valor?.toString() ?? "Não informado",
              style: const TextStyle(fontSize: 15),
            ),
          )
        ],
      ),
    );
  }
}
