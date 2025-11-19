import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'pages/formulario_saat_page.dart';

/// Ponto de entrada do aplicativo SAAT.
/// Aqui inicializamos o Supabase e definimos a tela inicial.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase com as chaves do seu projeto.
  await Supabase.initialize(
    url: 'https://bhhircniqqqdpeorwueu.supabase.co', // 🔹 Substitua pelo seu Project URL
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJoaGlyY25pcXFxZHBlb3J3dWV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMzMyOTQsImV4cCI6MjA3NzYwOTI5NH0.GfdMTDL0gO_1utyRFHIN1Pl11v1y2U7I2y5Qlwlu4gY', // 🔹 Substitua pela sua Anon Public Key
  );

  runApp(const SAATApp());
}

/// Cliente global do Supabase (para ser usado em todo o app)
final supabase = Supabase.instance.client;

/// Widget raiz do aplicativo
class SAATApp extends StatelessWidget {
  const SAATApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAAT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const AuthCheck(),
      routes: {
        '/home': (_) => const HomePage(),
        '/form': (_) => const FormularioSAATPage(), // 🔹 Nova rota para formulário
      },
    );
  }
}

/// Verifica se há sessão ativa do usuário.
/// Se estiver logado → HomePage
/// Se não → LoginPage
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    return session == null ? const LoginPage() : const HomePage();
  }
}
