import 'package:flutter/material.dart';
import 'package:mangas/services/filesystem.dart';
import './screens/favorites.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MyFS.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mangas Offline',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const FavoritesPage(),
    );
  }
}
