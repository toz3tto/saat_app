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

  // Controllers existentes
  final _solicitante = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _cidade = TextEditingController();
  final _equipamento = TextEditingController();
  final _problema = TextEditingController();
  final _nomeCliente = TextEditingController();
  final _cpfCnpjCliente = TextEditingController();
  final _nomeCompleto = TextEditingController();
  final _matricula = TextEditingController();

  // 🆕 NOVOS CAMPOS
  final _endereco = TextEditingController();
  final _cep = TextEditingController();
  final _bairro = TextEditingController();
  final _numero = TextEditingController();
  final _complemento = TextEditingController();

  String tipoSolicitante = 'Cliente';
  bool enviando = false;
  final List<XFile> _imagens = [];
  final ImagePicker _picker = ImagePicker();

  // Máscaras
  var maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp('[0-9]')});
  var maskTelefone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp('[0-9]')});
  var maskCep = MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp('[0-9]')});

  Future<void> _selecionarImagens() async {
    if (_imagens.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite máximo de 6 imagens atingido.')),
      );
      return;
    }

    final List<XFile> selecionadas = await _picker.pickMultiImage();
    if (selecionadas.isNotEmpty) {
      setState(() {
        if (_imagens.length + selecionadas.length <= 6) {
          _imagens.addAll(selecionadas);
        } else {
          _imagens.addAll(selecionadas.take(6 - _imagens.length));
        }
      });
    }
  }

  Future<void> enviarChamado() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => enviando = true);

    try {
      List<String> urlsImagens = [];

      for (final imagem in _imagens) {
        final bytes = await imagem.readAsBytes();
        final fileName = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage.from('saat_uploads').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );

        final url = supabase.storage.from('saat_uploads').getPublicUrl(fileName);
        urlsImagens.add(url);
      }

      await supabase.from('saat_chamados').insert({
        'solicitante': _solicitante.text,
        'telefone': _telefone.text,
        'email': _email.text,
        'cidade': _cidade.text,
        'equipamento': _equipamento.text,
        'problema_relatado': _problema.text,
        'tipo_solicitante': tipoSolicitante,
        'status_chamado': 'Pendente',
        'nome_cliente': _nomeCliente.text,
        'cpf_cnpj_cliente': _cpfCnpjCliente.text,
        'nome_completo': _nomeCompleto.text,
        'matricula': _matricula.text,

        // 🆕 CAMPOS ADICIONADOS
        'endereco': _endereco.text,
        'cep': _cep.text,
        'bairro': _bairro.text,
        'numero': _numero.text,
        'complemento': _complemento.text,

        'fotos': urlsImagens,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado enviado com sucesso!')),
      );

      _formKey.currentState!.reset();
      setState(() => _imagens.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar chamado: $e')),
      );
    } finally {
      setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final bool isMobile = largura < 700;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Formulário de Atendimento - SAAT'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: isMobile ? double.infinity : 650,
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: const [
                        Icon(Icons.build_circle_outlined, size: 55, color: Colors.blueAccent),
                        SizedBox(height: 8),
                        Text(
                          'Chamado SAAT',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _dropdown(isMobile),
                  const SizedBox(height: 16),

                  // CAMPOS DE CLIENTE / TÉCNICO / GESTOR
                  if (tipoSolicitante == 'Cliente') ...[
                    _campo(_nomeCliente, 'Nome do Cliente', true, Icons.person, isMobile),
                    const SizedBox(height: 16),
                    _campoFormatado(_cpfCnpjCliente, 'CPF/CNPJ do Cliente', true, Icons.badge, maskCpf, isMobile),
                    const SizedBox(height: 16),
                  ],

                  if (tipoSolicitante != 'Cliente') ...[
                    _campo(_nomeCompleto, 'Nome Completo', true, Icons.person_outline, isMobile),
                    const SizedBox(height: 16),
                    _campo(_matricula, 'Matrícula', true, Icons.badge_outlined, isMobile),
                    const SizedBox(height: 16),
                    _campo(_nomeCliente, 'Cliente', true, Icons.business, isMobile),
                    const SizedBox(height: 16),
                    _campoFormatado(_cpfCnpjCliente, 'CPF/CNPJ do Cliente', true, Icons.badge, maskCpf, isMobile),
                    const SizedBox(height: 16),
                  ],

                  // 📍 CAMPOS DE CONTATO
                  _campoFormatado(_telefone, 'Telefone', false, Icons.phone, maskTelefone, isMobile),
                  const SizedBox(height: 16),
                  _campo(_email, 'E-mail (opcional)', false, Icons.email, isMobile),
                  const SizedBox(height: 16),

                  // 📍 ENDEREÇO COMPLETO – ORDEM LÓGICA
                  _campo(_cidade, 'Cidade', false, Icons.location_city, isMobile),
                  const SizedBox(height: 16),
                  _campo(_endereco, 'Endereço', false, Icons.home, isMobile),
                  const SizedBox(height: 16),
                  _campoFormatado(_cep, 'CEP', false, Icons.location_searching, maskCep, isMobile),
                  const SizedBox(height: 16),
                  _campo(_bairro, 'Bairro', false, Icons.map, isMobile),
                  const SizedBox(height: 16),
                  _campo(_numero, 'Número', false, Icons.pin, isMobile),
                  const SizedBox(height: 16),
                  _campo(_complemento, 'Complemento', false, Icons.edit_location_alt, isMobile),
                  const SizedBox(height: 16),

                  // 📍 EQUIPAMENTO
                  _campo(_equipamento, 'Equipamento', false, Icons.settings, isMobile),
                  const SizedBox(height: 16),

                  // PROBLEMA
                  TextFormField(
                    controller: _problema,
                    maxLines: isMobile ? 5 : 8,
                    decoration: InputDecoration(
                      labelText: 'Descreva o problema',
                      prefixIcon: const Icon(Icons.report),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 20),

                  _botaoImagem(),
                  const SizedBox(height: 20),

                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: enviando ? null : enviarChamado,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: Text(enviando ? 'Enviando...' : 'Enviar Chamado',
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
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

  Widget _botaoImagem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotos do problema (até 6)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._imagens.map((img) => FutureBuilder<Uint8List>(
                  future: img.readAsBytes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagens.remove(img)),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                )),
            if (_imagens.length < 6)
              GestureDetector(
                onTap: _selecionarImagens,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_a_photo, color: Colors.blueAccent, size: 30),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _campo(TextEditingController c, String label, bool obrigatorio, IconData icone, bool isMobile) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: obrigatorio ? (v) => v!.isEmpty ? 'Campo obrigatório' : null : null,
    );
  }

  Widget _campoFormatado(TextEditingController c, String label, bool obrigatorio, IconData icone,
      MaskTextInputFormatter formatter, bool isMobile) {
    return TextFormField(
      controller: c,
      inputFormatters: [formatter],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: obrigatorio ? (v) => v!.isEmpty ? 'Campo obrigatório' : null : null,
    );
  }

  Widget _dropdown(bool isMobile) {
    return DropdownButtonFormField<String>(
      value: tipoSolicitante,
      items: const [
        DropdownMenuItem(value: 'Cliente', child: Text('Cliente')),
        DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
        DropdownMenuItem(value: 'Gestor', child: Text('Gestor')),
      ],
      onChanged: (v) => setState(() => tipoSolicitante = v!),
      decoration: InputDecoration(
        labelText: 'Tipo de usuário',
        prefixIcon: const Icon(Icons.account_circle),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
