import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool carregando = false;
  bool modoLogin = true;

  Future<void> _autenticar() async {
    setState(() => carregando = true);
    try {
      if (modoLogin) {
        await supabase.auth.signInWithPassword(
          email: emailController.text,
          password: senhaController.text,
        );
      } else {
        await supabase.auth.signUp(
          email: emailController.text,
          password: senhaController.text,
        );
      }

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login SAAT')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
            TextField(controller: senhaController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregando ? null : _autenticar,
              child: carregando
                  ? const CircularProgressIndicator()
                  : Text(modoLogin ? 'Entrar' : 'Cadastrar'),
            ),
            TextButton(
              onPressed: () => setState(() => modoLogin = !modoLogin),
              child: Text(modoLogin ? 'Criar nova conta' : 'Já tenho uma conta'),
            ),
          ],
        ),
      ),
    );
  }
}
