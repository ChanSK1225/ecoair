import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/store_provider.dart';
import 'providers/community_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_layout.dart';
import 'theme/ecoair_theme.dart';
import 'services/otp_email_sender.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('EcoAir Flutter error: ${details.exceptionAsString()}');
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final OtpEmailSender otpEmailSender;
  const MyApp({super.key, this.otpEmailSender = const OtpEmailSender()});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(otpEmailSender: otpEmailSender),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) => MultiProvider(
          key: ValueKey('${auth.userId}:${auth.dataRevision}'),
          providers: [
            ChangeNotifierProvider(
              create: (_) => WeatherProvider(
                userId: auth.userId,
                initialize: auth.isAuthenticated,
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => StoreProvider(
                userId: auth.userId,
                initialize: auth.isAuthenticated,
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => CommunityProvider(
                userId: auth.userId,
                initialize: auth.isAuthenticated,
              ),
            ),
          ],
          child: MaterialApp(
            // A session change must discard routes from the previous session.
            key: ValueKey(auth.isAuthenticated),
            title: 'EcoAir Malaysia',
            debugShowCheckedModeBanner: false,
            theme: EcoAirTheme.light(),
            home: const AuthWrapper(),
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authProvider.isAuthenticated) {
      return const MainLayout();
    } else {
      return const LoginScreen();
    }
  }
}
