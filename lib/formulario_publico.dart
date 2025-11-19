import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class FormularioPublicoPage extends StatefulWidget {
  const FormularioPublicoPage({super.key});

  @override
  State<FormularioPublicoPage> createState() => _FormularioPublicoPageState();
}

class _FormularioPublicoPageState extends State<FormularioPublicoPage> {
  final _formKey = GlobalKey<FormState>();
  final _solicitante = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _cidade = TextEditingController();
  final _equipamento = TextEditingController();
  final _problema = TextEditingController();
  String tipoSolicitante = 'Cliente';
  bool enviando = false;

  Future<void> enviarChamado() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => enviando = true);

    try {
      final user = supabase.auth.currentUser;
      await supabase.from('saat_chamados').insert({
        'solicitante': _solicitante.text,
        'telefone': _telefone.text,
        'email': _email.text,
        'cidade': _cidade.text,
        'equipamento': _equipamento.text,
        'problema_relatado': _problema.text,
        'tipo_solicitante': tipoSolicitante,
        'status_chamado': 'Pendente',
        'usuario_id': user?.id, // se estiver logado
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado enviado com sucesso!')),
      );

      _formKey.currentState!.reset();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abrir Chamado')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: tipoSolicitante,
                items: const [
                  DropdownMenuItem(value: 'Cliente', child: Text('Cliente')),
                  DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
                  DropdownMenuItem(value: 'Gestor', child: Text('Gestor')),
                ],
                onChanged: (v) => setState(() => tipoSolicitante = v!),
                decoration: const InputDecoration(labelText: 'Tipo de usuário'),
              ),
              TextFormField(
                controller: _solicitante,
                decoration: const InputDecoration(labelText: 'Nome do solicitante'),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              TextFormField(
                controller: _telefone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email (opcional)'),
              ),
              TextFormField(
                controller: _cidade,
                decoration: const InputDecoration(labelText: 'Cidade'),
              ),
              TextFormField(
                controller: _equipamento,
                decoration: const InputDecoration(labelText: 'Equipamento'),
              ),
              TextFormField(
                controller: _problema,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Problema relatado'),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: enviando ? null : enviarChamado,
                icon: const Icon(Icons.send),
                label: Text(enviando ? 'Enviando...' : 'Enviar Chamado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
