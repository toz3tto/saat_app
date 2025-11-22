// -----------------------------------------------------------------------------
//  HOME PAGE COMPLETA — GESTOR + TÉCNICO
//  Com todas as informações restauradas + edição técnico/visita corrigida
// -----------------------------------------------------------------------------

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
  List<Map<String, dynamic>> tecnicos = [];

  bool carregando = true;
  bool isGestor = false;
  String? userId;

  bool _fabPressed = false;
  bool _fabHover = false;

  final Map<int, bool> _editHover = {};
  final Map<int, bool> _editPressed = {};

  @override
  void initState() {
    super.initState();
    _carregarPerfilEChamados();
    _carregarTecnicos();
  }

  // -----------------------------------------------------------------
  // PERFIL + CHAMADOS
  // -----------------------------------------------------------------
  Future<void> _carregarPerfilEChamados() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      userId = user.id;

      final perfil = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      setState(() {
        isGestor = perfil['role'] == 'gestor';
      });

      await carregarChamados();
    } catch (e) {
      debugPrint("Erro ao carregar perfil: $e");
      setState(() => isGestor = false);
    }
  }

  // -----------------------------------------------------------------
  // CARREGA TÉCNICOS DO SUPABASE
  // -----------------------------------------------------------------
  Future<void> _carregarTecnicos() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id, nome')
          .eq('role', 'tecnico');

      tecnicos = List<Map<String, dynamic>>.from(response);
      setState(() {});
    } catch (e) {
      debugPrint("Erro ao carregar técnicos: $e");
    }
  }

  // -----------------------------------------------------------------
  // LISTAR CHAMADOS
  // -----------------------------------------------------------------
  Future<void> carregarChamados() async {
    setState(() => carregando = true);

    try {
      List<Map<String, dynamic>> lista = [];

      if (kIsWeb) {
        final response = await supabase
            .from('saat_chamados')
            .select()
            .order('id', ascending: false);

        lista = List<Map<String, dynamic>>.from(response);
      } else {
        await SyncService.sincronizar();
        lista = await DBHelper.listarChamados();
      }

      if (!isGestor && userId != null) {
        lista = lista.where((c) => c['tecnico_responsavel'] == userId).toList();
      }

      setState(() {
        chamados = lista;
        carregando = false;
      });
    } catch (e) {
      debugPrint("Erro listar: $e");
      setState(() => carregando = false);
    }
  }

  // -----------------------------------------------------------------
  // ATUALIZAR STATUS
  // -----------------------------------------------------------------
  Future<void> atualizarStatus(int id, String novoStatus) async {
    if (!isGestor) return;

    try {
      await supabase
          .from('saat_chamados')
          .update({'status_chamado': novoStatus})
          .eq('id', id);

      carregarChamados();
    } catch (e) {
      debugPrint("Erro atualizar status: $e");
    }
  }

  // -----------------------------------------------------------------
  // MODAL EDITAR CHAMADO — CORRIGIDO
  // -----------------------------------------------------------------
  Future<void> _editarChamado(Map<String, dynamic> chamado) async {
    if (!isGestor) return;

    String? tecnicoSelecionado =
        chamado['tecnico_responsavel']?.toString();

    final observacoesController =
        TextEditingController(text: chamado['observacoes_internas'] ?? "");

    DateTime? dataVisita;

    if (chamado['data_visita'] != null) {
      try {
        dataVisita = DateTime.parse(chamado['data_visita']);
      } catch (_) {
        dataVisita = null;
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialog) {
          return AlertDialog(
            title: Text("Editar Chamado #${chamado['id']}"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: tecnicoSelecionado,
                    hint: const Text("Selecione um técnico"),
                    items: tecnicos.map((tec) {
                      return DropdownMenuItem<String>(
                        value: tec['id'].toString(),
                        child: Text(tec['nome']),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setDialog(() => tecnicoSelecionado = v);
                    },
                    decoration: const InputDecoration(
                      labelText: "Técnico responsável",
                      prefixIcon: Icon(Icons.engineering),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Data da visita",
                      prefixIcon: const Icon(Icons.calendar_today),
                      hintText: dataVisita == null
                          ? "Selecione"
                          : "${dataVisita!.day}/${dataVisita!.month}/${dataVisita!.year}",
                    ),
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: context,
                        locale: const Locale("pt", "BR"),
                        initialDate: dataVisita ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (dt != null) {
                        setDialog(() => dataVisita = dt);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

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
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                child: const Text("Salvar"),
                onPressed: () async {
                  await supabase
                      .from('saat_chamados')
                      .update({
                        'tecnico_responsavel': tecnicoSelecionado,
                        'data_visita': dataVisita?.toIso8601String(),
                        'observacoes_internas':
                            observacoesController.text.trim(),
                      })
                      .eq('id', chamado['id']);

                  Navigator.pop(context);
                  carregarChamados();
                },
              )
            ],
          );
        });
      },
    );
  }

  // -----------------------------------------------------------------
  // INTERFACE PRINCIPAL
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isGestor ? "Painel do Gestor" : "Painel do Técnico"),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: _animatedFAB(),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : chamados.isEmpty
              ? const Center(child: Text("Nenhum chamado encontrado."))
              : _listaChamados(),
    );
  }

  // -----------------------------------------------------------------
  // LISTA COMPLETA DOS CHAMADOS (VISUAL FINAL)
  // -----------------------------------------------------------------
  Widget _listaChamados() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chamados.length,
      itemBuilder: (context, i) {
        final c = chamados[i];

        String tecnicoNome = "-";
        if (c['tecnico_responsavel'] != null) {
          final t = tecnicos.firstWhere(
            (tec) => tec['id'].toString() == c['tecnico_responsavel'].toString(),
            orElse: () => <String, dynamic>{},
          );
          if (t.isNotEmpty) tecnicoNome = t['nome'];
        }

        String dataVisita = "Não definida";
        if (c['data_visita'] != null) {
          try {
            final dv = DateTime.parse(c['data_visita']);
            dataVisita = "${dv.day}/${dv.month}/${dv.year}";
          } catch (_) {}
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABEÇALHO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Chamado #${c['id']}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _corStatus(c['status_chamado']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      c['status_chamado'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _linha(Icons.category, "Tipo do Chamado", c['tipo_chamado']),
              _linha(Icons.person, "Cliente", c['nome_cliente']),
              _linha(Icons.location_on,
                  "Cidade", "${c['cidade']} / ${c['estado']}"),
              _linha(Icons.home_work, "Endereço", c['endereco_fazenda']),
              _linha(Icons.settings, "Equipamento", c['equipamento']),
              _linha(Icons.engineering, "Técnico", tecnicoNome),
              _linha(Icons.calendar_month, "Visita", dataVisita),

              if ((c['observacoes_internas'] ?? '').trim().isNotEmpty)
                _linha(Icons.notes, "Observações", c['observacoes_internas']),

              const SizedBox(height: 15),

              if (isGestor)
                Column(
                  children: [
                    DropdownButton<String>(
                      value: c['status_chamado'],
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: "Pendente", child: Text("Pendente")),
                        DropdownMenuItem(
                            value: "Em atendimento",
                            child: Text("Em atendimento")),
                        DropdownMenuItem(
                            value: "Finalizado", child: Text("Finalizado")),
                      ],
                      onChanged: (v) => atualizarStatus(c['id'], v!),
                    ),
                    const SizedBox(height: 10),
                    _animatedEditButton(c, i),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // ELEMENTO VISUAL DE LINHA
  // -----------------------------------------------------------------
  Widget _linha(IconData ic, String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(ic, size: 20, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(valor ?? "-")),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // COR DO STATUS
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  // BOTÃO ANIMADO (NOVO CHAMADO)
  // -----------------------------------------------------------------
  Widget _animatedFAB() {
    return MouseRegion(
      onEnter: (_) => setState(() => _fabHover = true),
      onExit: (_) => setState(() => _fabHover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _fabPressed = true),
        onTapUp: (_) => setState(() => _fabPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()
            ..scale(
              _fabPressed
                  ? 0.93
                  : _fabHover
                      ? 1.07
                      : 1.0,
            ),
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0066FF),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Novo Chamado",
                style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pushNamed(context, '/form'),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // BOTÃO EDITAR
  // -----------------------------------------------------------------
  Widget _animatedEditButton(
      Map<String, dynamic> chamado, int index) {
    _editHover[index] ??= false;
    _editPressed[index] ??= false;

    return MouseRegion(
      onEnter: (_) => setState(() => _editHover[index] = true),
      onExit: (_) => setState(() => _editHover[index] = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _editPressed[index] = true),
        onTapUp: (_) => setState(() => _editPressed[index] = false),
        onTap: () => _editarChamado(chamado),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          transform: Matrix4.identity()
            ..scale(
              _editPressed[index]!
                  ? 0.95
                  : _editHover[index]!
                      ? 1.05
                      : 1.0,
            ),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.blue.withOpacity(0.3),
                offset: const Offset(0, 3),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // LOGOUT
  // -----------------------------------------------------------------
  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}
