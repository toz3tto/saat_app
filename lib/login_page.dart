import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

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
    if (emailController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha e-mail e senha.")),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      if (modoLogin) {
        await supabase.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: senhaController.text.trim(),
        );
      } else {
        await supabase.auth.signUp(
          email: emailController.text.trim(),
          password: senhaController.text.trim(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Conta criada com sucesso! Faça login.")),
        );

        setState(() => modoLogin = true);
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');

    } on AuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro inesperado ao autenticar.")),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final bool isMobile = largura < 700;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Container(
          width: isMobile ? double.infinity : 420,
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 60, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(
                modoLogin ? 'Acessar Sistema' : 'Criar Conta',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: carregando ? null : _autenticar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: carregando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          modoLogin ? 'Entrar' : 'Cadastrar',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),

              TextButton(
                onPressed: () => setState(() => modoLogin = !modoLogin),
                child: Text(
                  modoLogin
                      ? 'Criar nova conta'
                      : 'Já tenho uma conta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
