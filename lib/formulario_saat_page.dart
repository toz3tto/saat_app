// ---------------------------------------------------------------------------
//  FORMULÁRIO COMPLETO — com responsavel_abertura & lógica final desejada
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'main.dart';

class FormularioSAATPage extends StatefulWidget {
  const FormularioSAATPage({super.key});

  @override
  State<FormularioSAATPage> createState() => _FormularioSAATPageState();
}

class _FormularioSAATPageState extends State<FormularioSAATPage> {
  final _formKey = GlobalKey<FormState>();

  // ===== CAMPOS DO FORMULÁRIO =====
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _cidade = TextEditingController();
  final _estado = TextEditingController();
  final _endereco = TextEditingController();

  final _equipamento = TextEditingController();
  final _problema = TextEditingController();

  final _nomeCliente = TextEditingController();
  final _cpfCnpjCliente = TextEditingController();

  final _nomeCompleto = TextEditingController();
  final _matricula = TextEditingController();

  String tipoSolicitante = 'Cliente'; // Cliente | Técnico | Gestor
  String tipoChamado = 'ORÇAMENTOS'; // Tipo do chamado

  bool enviando = false;

  final List<XFile> _imagens = [];
  final ImagePicker _picker = ImagePicker();

  final maskTelefone = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Controle de CPF/CNPJ
  bool isCnpj = false; // false = CPF, true = CNPJ
  bool _formatandoCpfCnpj = false;

  // ================================================================
  // Selecionar imagens (somente para SINISTRO / VISTORIA / VISITAS TECNICAS)
  // ================================================================
  Future<void> _selecionarImagens() async {
    if (_imagens.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite máximo de 6 imagens atingido.')),
      );
      return;
    }

    final selecionadas = await _picker.pickMultiImage();
    if (selecionadas.isEmpty) return;

    setState(() {
      final restante = 6 - _imagens.length;
      _imagens.addAll(selecionadas.take(restante));
    });
  }

  // ================================================================
  // Enviar Chamado
  // ================================================================
  Future<void> enviarChamado() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => enviando = true);

    try {
      List<String> urlsImagens = [];

      // Apenas tipos que permitem anexos
      final permiteFotos = tipoChamado == "SINISTRO" ||
          tipoChamado == "VISTORIAS" ||
          tipoChamado == "VISITAS TECNICAS";

      if (permiteFotos) {
        for (var imagem in _imagens) {
          final fileName = "foto_${DateTime.now().millisecondsSinceEpoch}.jpg";
          final bytes = await imagem.readAsBytes();

          await supabase.storage.from("saat_uploads").uploadBinary(
                fileName,
                bytes,
                fileOptions: const FileOptions(upsert: false),
              );

          urlsImagens.add(
            supabase.storage.from("saat_uploads").getPublicUrl(fileName),
          );
        }
      }

      // -------------------------
      //  SALVANDO NO SUPABASE
      // -------------------------
      await supabase.from("saat_chamados").insert({
        "tipo_chamado": tipoChamado,
        "tipo_solicitante": tipoSolicitante,
        "status_chamado": "Pendente",

        // quem está abrindo o chamado
        "responsavel_abertura": supabase.auth.currentUser?.id,

        // cliente / técnico / gestor
        "nome_cliente": _nomeCliente.text,
        "cpf_cnpj_cliente": _cpfCnpjCliente.text,
        "nome_completo": _nomeCompleto.text,
        "matricula": _matricula.text,

        // contato
        "telefone": _telefone.text,
        "email": _email.text,
        "cidade": _cidade.text,
        "estado": _estado.text,
        "endereco_fazenda": _endereco.text,

        // equipamento / problema
        "equipamento": _equipamento.text,
        "problema_relatado": _problema.text,

        // dados técnicos
        "usuario_id": supabase.auth.currentUser?.id,
        "tecnico_responsavel": null,
        "data_visita": null,
        "observacoes_internas": null,

        // fotos
        "fotos": urlsImagens,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chamado enviado com sucesso!")),
      );

      _formKey.currentState!.reset();

      setState(() {
        tipoChamado = "ORÇAMENTOS";
        tipoSolicitante = "Cliente";
        _imagens.clear();
        _estado.text = "";
        _cpfCnpjCliente.text = "";
        isCnpj = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro ao enviar: $e")));
    } finally {
      setState(() => enviando = false);
    }
  }

  // ================================================================
  // INTERFACE
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    final bool permiteFotos = tipoChamado == "SINISTRO" ||
        tipoChamado == "VISTORIAS" ||
        tipoChamado == "VISITAS TECNICAS";

    final bool descricaoTecnica = tipoChamado == "SINISTRO" ||
        tipoChamado == "VISTORIAS" ||
        tipoChamado == "VISITAS TECNICAS";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 1,
        automaticallyImplyLeading: false, // impede o AppBar de criar o back automático
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  "Formulário de Atendimento - SAAT",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48), // equilibrio visual
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: isMobile ? double.infinity : 650,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.build_circle,
                      size: 60, color: Colors.blueAccent),
                  const SizedBox(height: 10),
                  const Text(
                    "Cadastro de Chamado",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // -----------------------------
                  // Tipo do chamado
                  // -----------------------------
                  DropdownButtonFormField<String>(
                    value: tipoChamado,
                    decoration: _dec("Tipo do Chamado", Icons.category),
                    items: const [
                      DropdownMenuItem(
                          value: "ORÇAMENTOS", child: Text("ORÇAMENTOS")),
                      DropdownMenuItem(
                          value: "SINISTRO", child: Text("SINISTRO")),
                      DropdownMenuItem(
                          value: "TREINAMENTO", child: Text("TREINAMENTO")),
                      DropdownMenuItem(
                          value: "VISITAS TECNICAS",
                          child: Text("VISITAS TÉCNICAS")),
                    ],
                    onChanged: (v) => setState(() => tipoChamado = v!),
                  ),

                  const SizedBox(height: 16),

                  // -----------------------------
                  // Tipo de usuário
                  // -----------------------------
                  DropdownButtonFormField<String>(
                    value: tipoSolicitante,
                    decoration: _dec("Tipo de Usuário", Icons.person),
                    items: const [
                      DropdownMenuItem(value: "Cliente", child: Text("Cliente")),
                      DropdownMenuItem(
                          value: "Técnico", child: Text("Técnico")),
                      DropdownMenuItem(value: "Gestor", child: Text("Gestor")),
                    ],
                    onChanged: (v) => setState(() => tipoSolicitante = v!),
                  ),

                  const SizedBox(height: 16),

                  // -------------------------------------------------------
                  // CAMPOS ESPECÍFICOS POR TIPO DE USUÁRIO
                  // -------------------------------------------------------
                  if (tipoSolicitante == "Cliente") ...[
                    _campo(_nomeCliente, "Razão Social", true, Icons.business),
                    const SizedBox(height: 16),
                    _campoCpfCnpj(),
                    const SizedBox(height: 16),
                  ],

                  if (tipoSolicitante != "Cliente") ...[
                    _campo(
                        _nomeCompleto, "Nome Completo", true, Icons.person),
                    const SizedBox(height: 16),

                    _campo(_matricula, "Matrícula", true, Icons.badge),
                    const SizedBox(height: 16),

                    _campo(_nomeCliente, "Cliente / Fazenda", true,
                        Icons.business),
                    const SizedBox(height: 16),

                    _campoCpfCnpj(),
                    const SizedBox(height: 16),
                  ],

                  // -------------------------------------------------------
                  // CONTATO / LOCALIZAÇÃO
                  // -------------------------------------------------------
                  _campoFormatado(
                      _telefone, "Telefone", true, Icons.phone, maskTelefone),
                  const SizedBox(height: 16),

                  _campo(_email, "E-mail (opcional)", false, Icons.email),
                  const SizedBox(height: 16),

                  _campo(_cidade, "Cidade", true, Icons.location_city),
                  const SizedBox(height: 16),

                  _dropdownUF(),
                  const SizedBox(height: 16),

                  _campo(_endereco, "Endereço/Localização", true,
                      Icons.location_on),
                  const SizedBox(height: 16),

                  // -------------------------------------------------------
                  // EQUIPAMENTO E PROBLEMA
                  // -------------------------------------------------------
                  _campo(_equipamento, "Equipamento", true, Icons.settings),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _problema,
                    maxLines: 6,
                    decoration: _dec(
                      descricaoTecnica
                          ? "Descreva o problema"
                          : "Observação",
                      Icons.report_problem,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Campo obrigatório" : null,
                  ),

                  const SizedBox(height: 20),

                  // -------------------------------------------------------
                  // FOTOS (Somente para SINISTRO / VISTORIA / VISITA TECNICA)
                  // -------------------------------------------------------
                  if (permiteFotos) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Fotos do problema (até 6)",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._imagens.map(
                          (img) => FutureBuilder<Uint8List>(
                            future: img.readAsBytes(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }

                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      snap.data!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _imagens.remove(img)),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        if (_imagens.length < 6)
                          GestureDetector(
                            onTap: _selecionarImagens,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.blueAccent,
                                size: 32,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],

                  // -----------------------------
                  // BOTÃO DE ENVIO
                  // -----------------------------
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: enviando ? null : enviarChamado,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        enviando ? "Enviando..." : "Enviar Chamado",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // HELPERS
  // ================================================================
  InputDecoration _dec(String label, IconData icone) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icone),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _campo(
      TextEditingController c, String label, bool obrigatorio, IconData icone) {
    return TextFormField(
      controller: c,
      decoration: _dec(label, icone),
      validator: obrigatorio
          ? (v) => v == null || v.isEmpty ? "Campo obrigatório" : null
          : null,
    );
  }

  Widget _campoFormatado(
      TextEditingController c,
      String label,
      bool obrigatorio,
      IconData icone,
      MaskTextInputFormatter formatter) {
    return TextFormField(
      controller: c,
      inputFormatters: [formatter],
      decoration: _dec(label, icone),
      validator: obrigatorio
          ? (v) => v == null || v.isEmpty ? "Campo obrigatório" : null
          : null,
    );
  }

  // Campo específico para CPF/CNPJ com detecção de tipo e formatação manual
  Widget _campoCpfCnpj() {
    return TextFormField(
      controller: _cpfCnpjCliente,
      keyboardType: TextInputType.number,
      decoration: _dec("CPF/CNPJ", Icons.badge),
      onChanged: (value) {
        if (_formatandoCpfCnpj) return;

        _formatandoCpfCnpj = true;

        // mantém apenas dígitos
        String digits = value.replaceAll(RegExp(r'\D'), '');

        // limita no máximo a 14 dígitos
        if (digits.length > 14) {
          digits = digits.substring(0, 14);
        }

        String formatted;
        if (digits.length <= 11) {
          // CPF
          isCnpj = false;
          formatted = _formatCpf(digits);
        } else {
          // CNPJ
          isCnpj = true;
          formatted = _formatCnpj(digits);
        }

        _cpfCnpjCliente.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );

        _formatandoCpfCnpj = false;
      },
      validator: (v) {
        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');

        if (digits.isEmpty) return "Campo obrigatório";

        // 11 dígitos = CPF, 14 dígitos = CNPJ
        if (digits.length == 11 || digits.length == 14) {
          return null;
        }

        return "Digite um CPF (11 dígitos) ou CNPJ (14 dígitos)";
      },
    );
  }

  String _formatCpf(String digits) {
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatCnpj(String digits) {
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 14; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Widget _dropdownUF() {
    const ufs = [
      'AC',
      'AL',
      'AP',
      'AM',
      'BA',
      'CE',
      'DF',
      'ES',
      'GO',
      'MA',
      'MT',
      'MS',
      'MG',
      'PA',
      'PB',
      'PR',
      'PE',
      'PI',
      'RJ',
      'RN',
      'RS',
      'RO',
      'RR',
      'SC',
      'SP',
      'SE',
      'TO'
    ];

    return DropdownButtonFormField<String>(
      value: _estado.text.isEmpty ? null : _estado.text,
      items: ufs
          .map(
            (uf) => DropdownMenuItem(
              value: uf,
              child: Text(uf),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _estado.text = v ?? ''),
      decoration: _dec("Estado (UF)", Icons.map),
      validator: (v) => v == null ? "Selecione o estado" : null,
    );
  }
}
