import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'formulario_saat_page.dart';

/// Ponto de entrada do aplicativo SAAT.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase (compatível com Flutter Web)
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://bhhircniqqqdpeorwueu.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJoaGlyY25pcXFxZHBlb3J3dWV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMzMyOTQsImV4cCI6MjA3NzYwOTI5NH0.GfdMTDL0gO_1utyRFHIN1Pl11v1y2U7I2y5Qlwlu4gY',
    ),
  );

  runApp(const SAATApp());
}

/// Cliente global do Supabase
final supabase = Supabase.instance.client;

class SAATApp extends StatelessWidget {
  const SAATApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAAT',
      debugShowCheckedModeBanner: false,

      // 🌎 SUPORTE COMPLETO AO PT-BR
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],

      // 🔹 Rota padrão ao abrir no navegador
      initialRoute: '/login',

      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/form': (_) => const FormularioSAATPage(),

        // usado somente internamente
        '/auth': (_) => const AuthCheck(),
      },

      // 🔹 Flutter Web acessando "/" → redireciona para Login
      onGenerateRoute: (settings) {
        if (settings.name == '/' || settings.name == '') {
          return MaterialPageRoute(builder: (_) => const LoginPage());
        }
        return null;
      },
    );
  }
}

/// Verifica se o usuário está logado
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    // Se não estiver logado → Login
    if (session == null) {
      return const LoginPage();
    }

    // Se estiver logado → Home
    return const HomePage();
  }
}
