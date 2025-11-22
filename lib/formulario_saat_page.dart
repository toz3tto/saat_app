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

  final _solicitante = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _cidade = TextEditingController();
  final _estado = TextEditingController();
  final _endereco = TextEditingController();
  final _cep = TextEditingController();
  final _bairro = TextEditingController();
  final _numero = TextEditingController();
  final _complemento = TextEditingController();

  final _equipamento = TextEditingController();
  final _problema = TextEditingController();
  final _nomeCliente = TextEditingController();
  final _cpfCnpjCliente = TextEditingController();
  final _nomeCompleto = TextEditingController();
  final _matricula = TextEditingController();

  String tipoSolicitante = 'Cliente';
  bool enviando = false;

  final List<XFile> _imagens = [];
  final ImagePicker _picker = ImagePicker();

  var maskCpf = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  var maskCnpj = MaskTextInputFormatter(
      mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  var maskTelefone = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  var maskCep = MaskTextInputFormatter(
      mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

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
      // Upload das imagens para o bucket
      List<String> urlsImagens = [];
      for (final imagem in _imagens) {
        final bytes = await imagem.readAsBytes();
        final fileName = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('saat_uploads').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
        final url =
            supabase.storage.from('saat_uploads').getPublicUrl(fileName);
        urlsImagens.add(url);
      }

      await supabase.from('saat_chamados').insert({
        'solicitante': _solicitante.text,
        'telefone': _telefone.text,
        'email': _email.text,
        'cidade': _cidade.text,
        'estado': _estado.text,
        'endereco': _endereco.text,
        'numero': _numero.text,
        'bairro': _bairro.text,
        'cep': _cep.text,
        'complemento': _complemento.text,
        'equipamento': _equipamento.text,
        'problema_relatado': _problema.text,
        'tipo_solicitante': tipoSolicitante,
        'status_chamado': 'Pendente',
        'nome_cliente': _nomeCliente.text,
        'cpf_cnpj_cliente': _cpfCnpjCliente.text,
        'nome_completo': _nomeCompleto.text,
        'matricula': _matricula.text,
        'tecnico_responsavel': null,
        'data_visita': null,
        'observacoes_internas': null,
        'fotos': urlsImagens,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado enviado com sucesso!')),
      );
      _formKey.currentState!.reset();
      setState(() {
        _imagens.clear();
        _estado.text = '';
      });
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
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
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
                        Icon(Icons.build_circle_outlined,
                            size: 60, color: Colors.blueAccent),
                        SizedBox(height: 8),
                        Text(
                          'Chamado SAAT',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _dropdownTipoSolicitante(isMobile),
                  const SizedBox(height: 16),

                  if (tipoSolicitante == 'Cliente') ...[
                    _campo(_nomeCliente, 'Nome do Cliente', true,
                        Icons.business_outlined, isMobile),
                    const SizedBox(height: 16),
                    _campoCpfCnpj(_cpfCnpjCliente, 'CPF/CNPJ do Cliente', true,
                        isMobile),
                    const SizedBox(height: 16),
                  ],

                  if (tipoSolicitante == 'Técnico' ||
                      tipoSolicitante == 'Gestor') ...[
                    _campo(_nomeCompleto, 'Nome Completo', true,
                        Icons.person_outline, isMobile),
                    const SizedBox(height: 16),
                    _campo(_matricula, 'Matrícula', true, Icons.badge_outlined,
                        isMobile),
                    const SizedBox(height: 16),
                    _campo(_nomeCliente, 'Nome do Cliente', true,
                        Icons.business_outlined, isMobile),
                    const SizedBox(height: 16),
                    _campoCpfCnpj(
                        _cpfCnpjCliente, 'CNPJ do Cliente', true, isMobile),
                    const SizedBox(height: 16),
                  ],

                  _campoFormatado(_telefone, 'Telefone', false,
                      Icons.phone_outlined, maskTelefone, isMobile),
                  const SizedBox(height: 16),
                  _campo(_email, 'E-mail (opcional)', false,
                      Icons.email_outlined, isMobile),
                  const SizedBox(height: 16),

                  _campo(_cidade, 'Cidade', false,
                      Icons.location_city_outlined, isMobile),
                  const SizedBox(height: 16),
                  _dropdownEstado(isMobile),
                  const SizedBox(height: 16),
                  _campo(_endereco, 'Endereço', false,
                      Icons.location_on_outlined, isMobile),
                  const SizedBox(height: 16),
                  _campo(_numero, 'Número', false, Icons.tag, isMobile),
                  const SizedBox(height: 16),
                  _campo(_bairro, 'Bairro', false, Icons.map_outlined,
                      isMobile),
                  const SizedBox(height: 16),
                  _campoFormatado(_cep, 'CEP', false, Icons.local_post_office,
                      maskCep, isMobile),
                  const SizedBox(height: 16),
                  _campo(_complemento, 'Complemento', false,
                      Icons.info_outline, isMobile),
                  const SizedBox(height: 16),

                  _campo(_equipamento, 'Equipamento', false,
                      Icons.settings_outlined, isMobile),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _problema,
                    maxLines: isMobile ? 6 : 10,
                    decoration: InputDecoration(
                      labelText: 'Descreva o problema',
                      prefixIcon: const Icon(Icons.report_problem_outlined),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo obrigatório' : null,
                  ),

                  const SizedBox(height: 20),
                  _botaoImagem(),
                  const SizedBox(height: 20),

                  Center(
                    child: SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 18),
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                        ),
                        onPressed: enviando ? null : enviarChamado,
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white),
                        label: Text(
                          enviando ? 'Enviando...' : 'Enviar Chamado',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
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

  Widget _dropdownTipoSolicitante(bool isMobile) {
    return DropdownButtonFormField<String>(
      value: tipoSolicitante,
      items: const [
        DropdownMenuItem(value: 'Cliente', child: Text('Cliente')),
        DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
        DropdownMenuItem(value: 'Gestor', child: Text('Gestor')),
      ],
      onChanged: (v) => setState(() => tipoSolicitante = v ?? 'Cliente'),
      decoration: InputDecoration(
        labelText: 'Tipo de usuário',
        prefixIcon: const Icon(Icons.account_circle_outlined),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownEstado(bool isMobile) {
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
      value: _estado.text.isNotEmpty ? _estado.text : null,
      items: ufs
          .map((uf) => DropdownMenuItem(value: uf, child: Text(uf)))
          .toList(),
      onChanged: (v) => setState(() => _estado.text = v ?? ''),
      decoration: InputDecoration(
        labelText: 'Estado (UF)',
        prefixIcon: const Icon(Icons.map_outlined),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v == null ? 'Selecione o estado' : null,
    );
  }

  Widget _botaoImagem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos do problema (até 6)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._imagens.map(
              (img) => FutureBuilder<Uint8List>(
                future: img.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Image.memory(snapshot.data!,
                                fit: BoxFit.contain),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snapshot.data!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagens.remove(img)),
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
      ],
    );
  }

  Widget _campoCpfCnpj(TextEditingController controller, String label,
      bool obrigatorio, bool isMobile) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [maskCpf],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.badge_outlined),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(fontSize: isMobile ? 14 : 16),
      validator: obrigatorio
          ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null
          : null,
    );
  }

  Widget _campoFormatado(
      TextEditingController controller,
      String label,
      bool obrigatorio,
      IconData icon,
      MaskTextInputFormatter formatter,
      bool isMobile) {
    return TextFormField(
      controller: controller,
      inputFormatters: [formatter],
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(fontSize: isMobile ? 14 : 16),
      validator: obrigatorio
          ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null
          : null,
    );
  }

  Widget _campo(TextEditingController controller, String label,
      bool obrigatorio, IconData icon, bool isMobile) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(fontSize: isMobile ? 14 : 16),
      validator: obrigatorio
          ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null
          : null,
    );
  }
}
