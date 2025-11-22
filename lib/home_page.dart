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

  // Estados para animações
  bool _fabPressed = false;
  bool _fabHover = false;

  Map<int, bool> _editHover = {};
  Map<int, bool> _editPressed = {};

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
    if (!isGestor) return; // técnico não abre modal

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
      builder: (_) {
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
                            ? "${dataVisita!.day.toString().padLeft(2, '0')}/"
                                "${dataVisita!.month.toString().padLeft(2, '0')}/"
                                "${dataVisita!.year}"
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
                      decoration: const InputDecoration(
                        labelText: "Observações internas",
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancelar"),
                  onPressed: () => Navigator.pop(context),
                ),
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

                    Navigator.pop(context);
                    carregarChamados();
                  },
                  child: const Text("Salvar"),
                )
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

      floatingActionButton: _animatedFAB(),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chamados.length,
              itemBuilder: (context, i) {
                final c = chamados[i];

                final status = c['status_chamado'] ?? 'Pendente';
                final tecnico = c['tecnico_responsavel'] ?? '-';
                final cidade = c['cidade'] ?? '-';
                final estado = c['estado'] ?? '-';
                final obs = c['observacoes_internas'] ?? '';

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

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TÍTULO + STATUS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Chamado #${c['id']}",
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004AAD)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
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

                      const SizedBox(height: 14),

                      _linha(Icons.person, "Cliente", c['nome_cliente']),
                      _linha(Icons.location_on, "Cidade", "$cidade / $estado"),
                      _linha(Icons.settings, "Equipamento", c['equipamento']),
                      _linha(Icons.engineering, "Técnico", tecnico),
                      _linha(Icons.calendar_month, "Visita", dataVisitaStr),

                      if (obs.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _linha(Icons.note_alt, "Observações", obs),
                      ],

                      const SizedBox(height: 20),

                      // BOTÕES APENAS PARA GESTOR
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

                        const SizedBox(height: 10),
                        _animatedEditButton(c, i),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ------------------------------------------------------------
  //  WIDGETS COM ANIMAÇÃO
  // ------------------------------------------------------------

  Widget _animatedFAB() {
    return MouseRegion(
      onEnter: (_) => setState(() => _fabHover = true),
      onExit: (_) => setState(() => _fabHover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _fabPressed = true),
        onTapUp: (_) => setState(() => _fabPressed = false),
        onTapCancel: () => setState(() => _fabPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.identity()
            ..scale(_fabPressed
                ? 0.90
                : _fabHover
                    ? 1.07
                    : 1.0),
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/form'),
            backgroundColor: const Color(0xFF0066FF),
            elevation: 8,
            icon: const Icon(Icons.add, size: 26, color: Colors.white),
            label: const Text(
              'Novo Chamado',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedEditButton(Map<String, dynamic> chamado, int index) {
    _editHover[index] ??= false;
    _editPressed[index] ??= false;

    return MouseRegion(
      onEnter: (_) => setState(() => _editHover[index] = true),
      onExit: (_) => setState(() => _editHover[index] = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _editPressed[index] = true),
        onTapUp: (_) => setState(() => _editPressed[index] = false),
        onTapCancel: () => setState(() => _editPressed[index] = false),
        onTap: () => _editarChamado(chamado),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          transform: Matrix4.identity()
            ..scale(_editPressed[index]!
                ? 0.95
                : _editHover[index]!
                    ? 1.05
                    : 1.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0066FF),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_accounts, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "Editar técnico / visita",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linha(IconData icone, String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icone, size: 22, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Expanded(
            child: Text(
              valor?.toString() ?? "-",
              style: const TextStyle(fontSize: 15),
            ),
          )
        ],
      ),
    );
  }
}
