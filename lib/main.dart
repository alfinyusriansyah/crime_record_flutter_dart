import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'db/crime_sqlite_repository.dart';
import 'dart:async';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set default locale & load data lokal untuk 'id_ID'
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID', null);

  // Bersihkan path gambar yang tidak valid di database
  await CrimeSqliteRepository.instance.fixInvalidPhotoPaths();

   // Tangkap error UI framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    Zone.current.handleUncaughtError(details.exception, details.stack!);
  };

  // Tangkap semua uncaught error (release pun ketangkap)
  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    // Kirim ke log / analytics Anda di sini
    // print('Uncaught: $error\n$stack');
  });

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crime Reporting App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 42, 62, 71)),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      home: const HomePage(),
    );
  }
}
