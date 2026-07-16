import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/student_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final container = ProviderContainer();
  final appState = container.read(appStateProvider);
  await appState.init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    
    return MaterialApp(
          title: 'Saimum Agent',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            primaryColor: const Color(0xFFFF751F),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF751F),
              primary: const Color(0xFFFF751F),
              secondary: const Color(0xFFFF9F43),
            ),
            fontFamily: 'Roboto', // Fallback to system font
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFF751F),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          onGenerateRoute: (settings) {
            if (settings.name == '/students') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => StudentListScreen(
                  status: args['status']!,
                  title: args['title']!,
                ),
              );
            }
            return null;
          },
          home: appState.currentUser != null
              ? const HomeScreen()
              : const LoginScreen(),
        );
  }
}
