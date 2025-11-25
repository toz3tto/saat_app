// -----------------------------------------------------------------------------
//  HOME PAGE — GESTOR + TÉCNICO
//  OPÇÃO 01 — maxWidth = 1100 px (centralizado, não estica ao maximizar)
// -----------------------------------------------------------------------------

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // -------------------------------------------------------------------
  // Baixar TODAS as fotos de abertura de um chamado
  // -------------------------------------------------------------------
    Future<void> _baixarTodasFotos(List<String> fotos) async {
      for (final url in fotos) {
        if (url.isEmpty) continue;

        final fileName =
            Uri.decodeComponent(url.split('/').last.split('?').first);

        await baixarArquivo(url, fileName: fileName);
      }
    }


  // Filtros (apenas para gestor)
  String? _filtroTipo;
  String? _filtroStatus;

  @override
  void initState() {
    super.initState();
    _carregarPerfilEChamados();
    _carregarTecnicos();
  }

  // -------------------------------------------------------------------
  // 0) Sanitizar nome de arquivo para usar no Storage (sem acentos etc.)
  // -------------------------------------------------------------------
  String _sanitizeFileNameForStorage(String original) {
    var name = original.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
    if (name.isEmpty) return 'arquivo';

    const withAccent = 'áàãâäÁÀÃÂÄéèêëÉÈÊËíìîïÍÌÎÏóòõôöÓÒÕÔÖúùûüÚÙÛÜçÇñÑ';
    const withoutAccent = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcCnN';

    final sb = StringBuffer();
    for (final codeUnit in name.runes) {
      var ch = String.fromCharCode(codeUnit);
      final index = withAccent.indexOf(ch);
      if (index >= 0) {
        ch = withoutAccent[index];
      }
      sb.write(ch);
    }

    name = sb.toString();
    // Permite letras, números, espaço, ponto, traço e underline
    name = name.replaceAll(RegExp(r'[^\w .\-]'), '_');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    return name;
  }


  // Normaliza qualquer texto de status para uma das 3 opções oficiais
  String _normalizeStatus(String value) {
    final v = value.trim().toLowerCase(); // tira espaços e padroniza

    if (v.startsWith('pendente')) {
      return 'Pendente';
    }
    if (v.startsWith('em atendimento')) {
      return 'Em atendimento';
    }
    if (v.startsWith('finalizado')) {
      return 'Finalizado';
    }

    // Se vier algo estranho, cai como Pendente
    return 'Pendente';
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
      Future<void> baixarArquivo(String url, {String? fileName}) async {
        // Em mobile/desktop nativo: só abre o link normalmente
        if (!kIsWeb) {
          try {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } catch (_) {}
          return;
        }

        // Nome que será sugerido no download (usa o original se vier)
        final nome = fileName ??
            Uri.decodeComponent(
              url.split('/').last.split('?').first,
            );

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
                if (kIsWeb) {
                  final uploadInput = html.FileUploadInputElement()
                    ..multiple = true
                    ..accept =
                        '.jpg,.jpeg,.png,.webp,.xls,.xlsx,.doc,.docx,.odf,.odt,.pdf';

                  uploadInput.click();

                  await uploadInput.onChange.first;

                  final files = uploadInput.files;
                  if (files == null || files.isEmpty) return;

                  for (final file in files) {
                    final reader = html.FileReader();
                    reader.readAsArrayBuffer(file);

                    await reader.onLoad.first;

                    final result = reader.result;
                    if (result == null) continue;

                    Uint8List bytes;

                    if (result is ByteBuffer) {
                      bytes = Uint8List.view(result);
                    } else if (result is Uint8List) {
                      bytes = result;
                    } else {
                      continue;
                    }

                    final originalName = file.name;
                    final safeName = _sanitizeFileNameForStorage(originalName);

                    final storageKey =
                        "chamado_${chamadoId}_${DateTime.now().millisecondsSinceEpoch}_$safeName";

                    await supabase.storage
                        .from('saat_uploads')
                        .uploadBinary(storageKey, bytes);

                    final url = supabase.storage
                        .from('saat_uploads')
                        .getPublicUrl(storageKey);

                    await supabase.from('saat_arquivos').insert({
                      'chamado_id': chamadoId,
                      'tipo': originalName, // nome original
                      'url': url,
                    });
                  }
                } else {
                  final result = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    type: FileType.custom,
                    allowedExtensions: [
                      'jpg',
                      'jpeg',
                      'png',
                      'webp',
                      'xls',
                      'xlsx',
                      'doc',
                      'docx',
                      'odf',
                      'odt',
                      'pdf',
                    ],
                    withData: true,
                  );

                  if (result == null || result.files.isEmpty) return;

                  for (final file in result.files) {
                    final bytes = file.bytes;
                    if (bytes == null) continue;

                    final originalName = file.name;
                    final safeName = _sanitizeFileNameForStorage(originalName);

                    final storageKey =
                        "chamado_${chamadoId}_${DateTime.now().millisecondsSinceEpoch}_$safeName";

                    await supabase.storage
                        .from('saat_uploads')
                        .uploadBinary(storageKey, bytes);

                    final url = supabase.storage
                        .from('saat_uploads')
                        .getPublicUrl(storageKey);

                    await supabase.from('saat_arquivos').insert({
                      'chamado_id': chamadoId,
                      'tipo': originalName,
                      'url': url,
                    });
                  }
                }

                await carregarAnexos();
                setDialog(() {});
              } catch (e) {
                debugPrint("Erro ao adicionar anexos: $e");
              }
            }

           
            // --------------------------
            // EXCLUIR ARQUIVO
            // --------------------------
            Future<void> deletarAnexo(Map<String, dynamic> arq) async {
              try {
                final dynamic rawId = arq['id'];
                final String url = (arq['url'] ?? '').toString();

                // Confirmação
                final confirma = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Remover arquivo"),
                    content: const Text(
                        "Tem certeza que deseja excluir este arquivo?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancelar"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Excluir",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirma != true) return;

                // Converte ID para int de forma segura
                int? id;
                if (rawId is int) {
                  id = rawId;
                } else {
                  id = int.tryParse(rawId.toString());
                }

                if (id == null) {
                  debugPrint('ID do anexo inválido: $rawId');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erro ao excluir: ID inválido.')),
                    );
                  }
                  return;
                }

                // 1) tentar remover do storage (melhor esforço)
                if (url.isNotEmpty) {
                  String storageKey = '';
                  try {
                    final uri = Uri.parse(url);
                    if (uri.pathSegments.isNotEmpty) {
                      storageKey = uri.pathSegments.last;
                    }
                  } catch (_) {
                    storageKey = url.split('/').last.split('?').first;
                  }

                  if (storageKey.isNotEmpty) {
                    try {
                      await supabase.storage
                          .from('saat_uploads')
                          .remove([storageKey]);
                    } catch (e) {
                      debugPrint(
                          "Falha ao remover do storage (segue mesmo assim): $e");
                    }
                  }
                }

                // 2) remover do banco e verificar se alguma linha foi apagada
                final deleted = await supabase
                    .from('saat_arquivos')
                    .delete()
                    .eq('id', id)
                    .select(); // retorna as linhas deletadas

                debugPrint("Deleted rows: $deleted");

                if (deleted is List && deleted.isEmpty) {
                  // Nada foi apagado no banco (provavelmente RLS ou filtro não bateu)
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Não foi possível excluir no banco. Verifique as policies da tabela saat_arquivos no Supabase.',
                        ),
                      ),
                    );
                  }
                }

                // 3) remover da lista local e atualizar UI
                anexos.removeWhere((a) => a['id'] == id);
                setDialog(() {});
              } catch (e) {
                debugPrint("Erro ao excluir anexo: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao excluir anexo.')),
                  );
                }
              }
            }


            // --------------------------
            // ABRIR URL (download)
            // --------------------------
            Future<void> abrirUrl(String url, String fileName) async {
              await baixarArquivo(url, fileName: fileName);
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
          content: anexos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                  child: Text(
                    "Nenhum arquivo anexado ainda.",
                    textAlign: TextAlign.center,
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                    maxWidth: 450,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: anexos.map((arq) {
                        final String url = (arq['url'] ?? '').toString();
                        final String rawTipo = (arq['tipo'] ?? '').toString();

                        String nomeArquivo;
                        if (rawTipo.trim().isNotEmpty &&
                            rawTipo != 'anexo' &&
                            rawTipo != 'imagem') {
                          nomeArquivo = rawTipo;
                        } else {
                          nomeArquivo = Uri.decodeComponent(
                            url.split('/').last.split('?').first,
                          );
                        }

                        final String ext = nomeArquivo.contains('.')
                            ? nomeArquivo.split('.').last.toLowerCase()
                            : 'arquivo';

                        final bool isImage = [
                          'jpg',
                          'jpeg',
                          'png',
                          'webp'
                        ].contains(ext);

                        IconData iconeArquivo;
                        if (['xls', 'xlsx'].contains(ext)) {
                          iconeArquivo = Icons.grid_on;
                        } else if (['doc', 'docx', 'odt', 'odf'].contains(ext)) {
                          iconeArquivo = Icons.description;
                        } else if (ext == 'pdf') {
                          iconeArquivo = Icons.picture_as_pdf;
                        } else {
                          iconeArquivo = Icons.insert_drive_file;
                        }

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
                                : Icon(iconeArquivo),
                            title: Text(
                              nomeArquivo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              ext.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => abrirUrl(url, nomeArquivo),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => deletarAnexo(arq),
                                ),
                              ],
                            ),
                            onTap: isImage
                                ? () => _abrirImagem(url)
                                : () => abrirUrl(url, nomeArquivo),
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
  // 8) VISUALIZAR IMAGEM EM TELA CHEIA (com fundo cinza + download)
  // -------------------------------------------------------------------
      Future<void> _abrirImagem(String url) async {
        // Nome do arquivo para usar no download
        final String fileName =
            Uri.decodeComponent(url.split('/').last.split('?').first);

        await showDialog(
          context: context,
          barrierColor: Colors.black87.withOpacity(0.8), // overlay escuro
          builder: (_) {
            return Dialog(
              backgroundColor: Colors.grey[900], // fundo do dialog cinza escuro
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                color: Colors.grey[900],
                child: Stack(
                  children: [
                    // Imagem centralizada com zoom
                    Center(
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // Botões (download + fechar) no canto superior direito
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Baixar imagem',
                            icon: const Icon(Icons.download, color: Colors.white),
                            onPressed: () async {
                              await baixarArquivo(url, fileName: fileName);
                            },
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
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
// 9) WIDGET DE FILTROS (GESTOR)
// -------------------------------------------------------------------
Widget _filtrosGestor() {
  // Monta listas únicas de tipo e status
  final tiposSet = <String>{};
  final statusSet = <String>{};

  for (final c in chamados) {
    final t = (c['tipo_chamado'] ?? '').toString().trim();
    if (t.isNotEmpty) tiposSet.add(t);

    final sRaw = (c['status_chamado'] ?? '').toString();
    final s = _normalizeStatus(sRaw);
    if (s.isNotEmpty) statusSet.add(s);
  }

  final tipos = tiposSet.toList()..sort();
  final status = statusSet.toList()..sort();

  // Garante que o value SEMPRE exista na lista
  String? currentTipo = _filtroTipo;
  if (currentTipo != null && !tipos.contains(currentTipo)) {
    currentTipo = null;
  }

  String? currentStatus = _filtroStatus;
  if (currentStatus != null && !status.contains(currentStatus)) {
    currentStatus = null;
  }

  // cor mais clara pros campos
  const fieldBg = Color(0xFFF3F3F3); // bem clarinho

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.black54),
      filled: true,
      fillColor: fieldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black87, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  return Card(
    color: const Color(0xFFF7F7F7),
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // FILTRO TIPO
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: currentTipo,
              dropdownColor: Colors.white,
              decoration: _dec("Tipo de chamado", Icons.filter_list),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Todos os tipos"),
                ),
                ...tipos.map(
                  (t) => DropdownMenuItem<String?>(
                    value: t,
                    child: Text(
                      t,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _filtroTipo = value;
                });
              },
            ),
          ),

          const SizedBox(width: 12),

          // FILTRO STATUS
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: currentStatus,
              dropdownColor: Colors.white,
              decoration: _dec("Status", Icons.checklist),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Todos os status"),
                ),
                ...status.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s,
                    child: Text(
                      s,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _filtroStatus = value;
                });
              },
            ),
          ),
        ],
      ),
    ),
  );
}


  // -------------------------------------------------------------------
  // 10) UI PRINCIPAL — COM maxWidth = 1100 (OPÇÃO 01)
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

       appBar: AppBar(
          backgroundColor: Colors.white, // bem mais claro
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
        alignment: Alignment.topLeft,
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
                    : isGestor
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _filtrosGestor(),
                              const SizedBox(height: 8),
                              Expanded(child: _listaChamados()),
                            ],
                          )
                        : _listaChamados(),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 11) LISTA DE CHAMADOS — com filtros aplicados
  // -------------------------------------------------------------------
  

// -------------------------------------------------------------------
// 11) LISTA DE CHAMADOS — com filtros aplicados
// -------------------------------------------------------------------
Widget _listaChamados() {
  // Aplica filtros (se houver)
  List<Map<String, dynamic>> lista =
      List<Map<String, dynamic>>.from(chamados);

  if (_filtroTipo != null && _filtroTipo!.isNotEmpty) {
    lista = lista
        .where((c) =>
            (c['tipo_chamado'] ?? '').toString().trim() == _filtroTipo)
        .toList();
  }

  if (_filtroStatus != null && _filtroStatus!.isNotEmpty) {
    lista = lista
        .where((c) =>
            _normalizeStatus((c['status_chamado'] ?? '').toString()) ==
            _filtroStatus)
        .toList();
  }

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: lista.length,
    itemBuilder: (context, i) {
      final c = lista[i];

      final String status =
          _normalizeStatus((c['status_chamado'] ?? "Pendente").toString());
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
            // CABEÇALHO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CHAMADO #${c['id']}",
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

            // DUAS COLUNAS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _linha(Icons.settings, "Equipamento", equipamento),
                      _linha(Icons.engineering, "Técnico", tecnicoNome),
                      _linha(Icons.calendar_month, "Visita", dataVisitaStr),
                      if (observacoes.trim().isNotEmpty)
                        _linha(Icons.notes, "Observações", observacoes),
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

              Row(
                children: [
                  const Text(
                    "FOTOS DA ABERTURA:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                          TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            // sem foregroundColor pra não forçar a cor no ícone
                          ),
                          onPressed: () => _baixarTodasFotos(fotos),
                          icon: const Icon(
                            Icons.download,
                            size: 16,
                            color: Colors.red, // flechinha vermelha
                          ),
                          label: const Text(
                            "Baixar todas",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green, // texto verde
                            ),
                          ),
                        ),
                ],
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

            // STATUS + EDITAR (GESTOR)
            if (isGestor) ...[
              const Text(
                "Status:",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
             Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFFF3F3F3), // mesma cor clara dos filtros
                ),
                child: DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  dropdownColor: const Color(0xFFF3F3F3),
                  style: const TextStyle(color: Colors.black87),
                  iconEnabledColor: Colors.black87,
                  items: const [
                    DropdownMenuItem(
                      value: "Pendente",
                      child: Text("Pendente"),
                    ),
                    DropdownMenuItem(
                      value: "Em atendimento",
                      child: Text("Em atendimento"),
                    ),
                    DropdownMenuItem(
                      value: "Finalizado",
                      child: Text("Finalizado"),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) atualizarStatus(c['id'], v);
                  },
                ),
              ),

              const SizedBox(height: 14),
              _animatedEditButton(c, i),
            ],

            const SizedBox(height: 18),

            // BOTÃO ARQUIVOS
           Align(
                alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                  onPressed: () => _abrirArquivosChamado(c),
                  style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[800],
                ),
                icon: Icon(Icons.attach_file, color: Colors.grey[800]),
                label: Text(
                  "Arquivos / Fotos adicionais",
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          ],
        ),
      );
    },
  );
}



  // -------------------------------------------------------------------
  // 12) Linha com ícone + label + valor
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
  // 13) Cor do chip do status
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
// 14) FAB Novo Chamado + animação
// -------------------------------------------------------------------
Widget _animatedFAB() {
  return MouseRegion(
    onEnter: (_) => setState(() => _fabHover = true),
    onExit: (_) => setState(() => _fabHover = false),
    child: GestureDetector(
      // agora o GestureDetector só cuida da animação
      onTapDown: (_) => setState(() => _fabPressed = true),
      onTapUp: (_) => setState(() => _fabPressed = false),
      onTapCancel: () => setState(() => _fabPressed = false),
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
          // >>> ESSA LINHA É O QUE FALTAVA <<<
          onPressed: () => Navigator.pushNamed(context, '/form'),
        ),
      ),
    ),
  );
}


    // -------------------------------------------------------------------
    // 15) Botão "Editar técnico / visita" com animação
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
              color: const Color(0xFF0066FF), // azul
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
  // 16) Logout
  // -------------------------------------------------------------------
  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}
