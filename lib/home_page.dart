// -----------------------------------------------------------------------------
//  HOME PAGE — GESTOR + TÉCNICO
//  OPÇÃO 01 — maxWidth = 1100 px (centralizado, não estica ao maximizar)
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

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

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _carregarPerfilEChamados();
    _carregarTecnicos();
  }

  // -------------------------------------------------------------------
  // 1) CARREGAR PERFIL + CHAMADOS
  // -------------------------------------------------------------------
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
      debugPrint("Erro carregar perfil: $e");
      setState(() => isGestor = false);
    }
  }

  // -------------------------------------------------------------------
  // 2) CARREGAR TÉCNICOS
  // -------------------------------------------------------------------
  Future<void> _carregarTecnicos() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id, nome')
          .eq('role', 'tecnico');

      tecnicos = List<Map<String, dynamic>>.from(response);
      setState(() {});
    } catch (e) {
      debugPrint("Erro técnicos: $e");
    }
  }

  // -------------------------------------------------------------------
  // 3) LISTAR CHAMADOS
  // -------------------------------------------------------------------
  Future<void> carregarChamados() async {
    setState(() => carregando = true);

    try {
      List<Map<String, dynamic>> lista = [];

      if (kIsWeb) {
        final response = await supabase
            .from('saat_chamados')
            .select()
            .order('id', ascending: true);

        lista = List<Map<String, dynamic>>.from(response);
      } else {
        await SyncService.sincronizar();
        lista = await DBHelper.listarChamados();
      }

      if (!isGestor && userId != null) {
        lista =
            lista.where((c) => c['tecnico_responsavel'] == userId).toList();
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
  // -------------------------------------------------------------------
  // 4) ATUALIZAR STATUS (somente gestor)
  // -------------------------------------------------------------------
  Future<void> atualizarStatus(int id, String novoStatus) async {
    if (!isGestor) return;

    try {
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
    } catch (e) {
      debugPrint("Erro atualizar status: $e");
    }
  }

  // -------------------------------------------------------------------
  // 5) EDITAR CHAMADO (gestor)
  // -------------------------------------------------------------------
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
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                "Editar Chamado #${chamado['id']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tecnicoSelecionado,
                      decoration: const InputDecoration(
                        labelText: "Técnico responsável",
                        prefixIcon: Icon(Icons.engineering),
                        border: OutlineInputBorder(),
                      ),
                      items: tecnicos.map((tec) {
                        return DropdownMenuItem<String>(
                          value: tec['id'].toString(),
                          child: Text(tec['nome'] ?? "Sem nome"),
                        );
                      }).toList(),
                      onChanged: (v) => setDialog(() => tecnicoSelecionado = v),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Data da visita",
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: const OutlineInputBorder(),
                        hintText: dataVisita == null
                            ? "Selecione"
                            : "${dataVisita!.day.toString().padLeft(2, '0')}/"
                                "${dataVisita!.month.toString().padLeft(2, '0')}/"
                                "${dataVisita!.year}",
                      ),
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: context,
                          locale: const Locale("pt", "BR"),
                          initialDate: dataVisita ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (dt != null) setDialog(() => dataVisita = dt);
                      },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: observacoesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Observações internas",
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(
                      color: Color(0xFF0066FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
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
                  child: const Text(
                    "Salvar",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // 6) DOWNLOAD FORÇADO NO FLUTTER WEB
  // -------------------------------------------------------------------
  Future<void> baixarArquivo(String url) async {
    if (!kIsWeb) {
      try {
        await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }

    final nome = url.split('/').last;

    try {
      final response = await html.HttpRequest.request(
        url,
        responseType: 'blob',
      );

      final blob = response.response;
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: blobUrl)
        ..download = nome
        ..style.display = 'none';

      html.document.body!.children.add(anchor);
      anchor.click();

      html.document.body!.children.remove(anchor);

      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      debugPrint("Erro ao baixar: $e");
    }
  }
  // -------------------------------------------------------------------
  // 7) MODAL DE ARQUIVOS + FOTOS ADICIONAIS
  // -------------------------------------------------------------------
  Future<void> _abrirArquivosChamado(Map<String, dynamic> chamado) async {
    final int chamadoId = chamado['id'];

    List<Map<String, dynamic>> anexos = [];

    Future<void> carregarAnexos() async {
      try {
        final resp = await supabase
            .from('saat_arquivos')
            .select('id, url, tipo')
            .eq('chamado_id', chamadoId)
            .order('id', ascending: true);

        anexos = List<Map<String, dynamic>>.from(resp);
      } catch (e) {
        debugPrint("Erro carregar anexos: $e");
      }
    }

    await carregarAnexos();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            // --------------------------
            // ADICIONAR ARQUIVOS
            // --------------------------
            Future<void> adicionarArquivos() async {
              try {
                final selecionadas = await _picker.pickMultiImage();
                if (selecionadas.isEmpty) return;

                for (final img in selecionadas) {
                  final fileName =
                      "anexo_${chamadoId}_${DateTime.now().millisecondsSinceEpoch}.jpg";

                  final bytes = await img.readAsBytes();

                  // Supabase Storage NOVO
                  await supabase.storage
                      .from('saat_uploads')
                      .uploadBinary(fileName, bytes);

                  final url = supabase.storage
                      .from('saat_uploads')
                      .getPublicUrl(fileName);

                  await supabase.from('saat_arquivos').insert({
                    'chamado_id': chamadoId,
                    'tipo': 'anexo',
                    'url': url,
                  });
                }

                await carregarAnexos();
                setDialog(() {});
              } catch (e) {
                debugPrint("Erro ao adicionar anexos: $e");
              }
            }

            // --------------------------
            // ABRIR URL (download)
            // --------------------------
            Future<void> abrirUrl(String url) async {
              await baixarArquivo(url);
            }

            return AlertDialog(
              backgroundColor: const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Arquivos do Chamado #$chamadoId",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              // --------------------------
              // LISTA DE ARQUIVOS
              // --------------------------
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                  maxWidth: 450,
                ),
                child: anexos.isEmpty
                    ? const Center(
                        child: Text("Nenhum arquivo anexado ainda."),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: anexos.map((arq) {
                            final String url =
                                (arq['url'] ?? '').toString();
                            final String tipo =
                                (arq['tipo'] ?? 'anexo').toString();

                            final isImage =
                                url.toLowerCase().endsWith(".jpg") ||
                                    url.toLowerCase().endsWith(".png") ||
                                    url.toLowerCase().endsWith(".jpeg") ||
                                    url.toLowerCase().endsWith(".webp");

                            return Card(
                              elevation: 2,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: isImage
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.insert_drive_file),

                                title: Text(
                                  tipo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),

                                subtitle: Text(
                                  url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                trailing: IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => abrirUrl(url),
                                ),

                                onTap: isImage
                                    ? () => _abrirImagem(url)
                                    : () => abrirUrl(url),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),

              // --------------------------
              // BOTÕES
              // --------------------------
              actionsPadding:
                  const EdgeInsets.only(bottom: 10, right: 20, left: 20),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  child: const Text(
                    "Fechar",
                    style: TextStyle(
                      color: Color(0xFF0066FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),

                TextButton.icon(
                  icon:
                      const Icon(Icons.attach_file, color: Color(0xFF0066FF)),
                  label: const Text(
                    "Adicionar",
                    style: TextStyle(
                      color: Color(0xFF0066FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: adicionarArquivos,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // 8) VISUALIZAR IMAGEM EM TELA CHEIA
  // -------------------------------------------------------------------
  Future<void> _abrirImagem(String url) async {
    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          child: InteractiveViewer(
            child: Stack(
              children: [
                Center(child: Image.network(url)),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // -------------------------------------------------------------------
  // 9) UI PRINCIPAL — COM maxWidth = 1100 (OPÇÃO 01)
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 1,
        title: Text(
          isGestor ? "Painel do Gestor" : "Painel do Técnico",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),

      floatingActionButton: _animatedFAB(),

    body: Align(
        alignment: Alignment.topLeft, // ou Alignment.centerLeft se preferir centralizado na vertical
        child: Padding(
          padding: const EdgeInsets.only(left: 24, top: 16, right: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : chamados.isEmpty
                    ? const Center(
                        child: Text(
                          "Nenhum chamado encontrado.",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : _listaChamados(),
          ),
        ),
      ),

    );
  }

  // -------------------------------------------------------------------
  // 10) LISTA DE CHAMADOS — com layout em duas colunas
  // -------------------------------------------------------------------
  Widget _listaChamados() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chamados.length,
      itemBuilder: (context, i) {
        final c = chamados[i];

        final String status = (c['status_chamado'] ?? "Pendente").toString();
        final String tipo = (c['tipo_chamado'] ?? "-").toString();
        final String cidade = (c['cidade'] ?? "-").toString();
        final String estado = (c['estado'] ?? "-").toString();
        final String endereco = (c['endereco_fazenda'] ?? "-").toString();
        final String cliente = (c['nome_cliente'] ?? "-").toString();
        final String equipamento = (c['equipamento'] ?? "-").toString();
        final String observacoes =
            (c['observacoes_internas'] ?? "").toString();

        // TÉCNICO RESPONSÁVEL
        String tecnicoNome = "-";
        if (c['tecnico_responsavel'] != null) {
          final found = tecnicos.firstWhere(
            (t) => t['id'].toString() == c['tecnico_responsavel'].toString(),
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) {
            tecnicoNome = (found['nome'] ?? "-").toString();
          }
        }

        // DATA DA VISITA
        String dataVisitaStr = "Não definida";
        if (c['data_visita'] != null) {
          try {
            final dv = DateTime.parse(c['data_visita']);
            dataVisitaStr =
                "${dv.day.toString().padLeft(2, '0')}/${dv.month.toString().padLeft(2, '0')}/${dv.year}";
          } catch (_) {}
        }

        // FOTOS DA ABERTURA
        List<String> fotos = [];
        if (c['fotos'] is List) {
          fotos = (c['fotos'] as List).map((e) => e.toString()).toList();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
              // -----------------------------------------------------------
              // CABEÇALHO DO CARD
              // -----------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Chamado #${c['id']}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _corStatus(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // -----------------------------------------------------------
              // DUAS COLUNAS 50/50
              // -----------------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COLUNA ESQUERDA
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _linha(Icons.category, "Tipo", tipo),
                        _linha(Icons.person, "Cliente", cliente),
                        _linha(Icons.location_on,
                            "Cidade", "$cidade / $estado"),
                        _linha(Icons.home_work, "Endereço", endereco),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // COLUNA DIREITA
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _linha(Icons.settings, "Equipamento", equipamento),
                        _linha(Icons.engineering, "Técnico", tecnicoNome),
                        _linha(Icons.calendar_month, "Visita", dataVisitaStr),

                        if (observacoes.trim().isNotEmpty)
                          _linha(Icons.notes,
                              "Observações", observacoes),
                      ],
                    ),
                  ),
                ],
              ),

              // -----------------------------------------------------------
              // FOTOS DA ABERTURA
              // -----------------------------------------------------------
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  "FOTOS DA ABERTURA:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: fotos.map((url) {
                      return GestureDetector(
                        onTap: () => _abrirImagem(url),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // -----------------------------------------------------------
              // STATUS + BOTÃO EDITAR (GESTOR)
              // -----------------------------------------------------------
              if (isGestor) ...[
                const Text(
                  "Status:",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                DropdownButton<String>(
                  value: status,
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
                  onChanged: (v) {
                    if (v != null) atualizarStatus(c['id'], v);
                  },
                ),

                const SizedBox(height: 14),

                _animatedEditButton(c, i),
              ],

              const SizedBox(height: 18),

              // -----------------------------------------------------------
              // BOTÃO ARQUIVOS / FOTOS ADICIONAIS
              // -----------------------------------------------------------
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _abrirArquivosChamado(c),
                  icon: const Icon(Icons.attach_file),
                  label: const Text("Arquivos / Fotos adicionais"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // -------------------------------------------------------------------
  // 11) Linha com ícone + label + valor (component padrão do card)
  // -------------------------------------------------------------------
  Widget _linha(IconData ic, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, size: 20, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: valor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // 12) Cor do chip do status
  // -------------------------------------------------------------------
  Color _corStatus(String status) {
    switch (status) {
      case "Finalizado":
        return Colors.green;
      case "Em atendimento":
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // -------------------------------------------------------------------
  // 13) FAB Novo Chamado + animação
  // -------------------------------------------------------------------
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
            ..scale(_fabPressed ? 0.93 : (_fabHover ? 1.07 : 1.0)),
          child: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0066FF),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Novo Chamado",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.pushNamed(context, '/form'),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 14) Botão "Editar técnico / visita" com animação
  // -------------------------------------------------------------------
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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          transform: Matrix4.identity()
            ..scale(
              _editPressed[index]! ? 0.95 : (_editHover[index]! ? 1.05 : 1.0),
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

  // -------------------------------------------------------------------
  // 15) Logout
  // -------------------------------------------------------------------
  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}
