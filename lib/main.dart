import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/albums_screen.dart';
import 'services/album_progress_service.dart';
import 'services/favorites_service.dart';
import 'services/trash_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  favorites.load();
  albumProgress.load();
  trashService.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SwipedelApp());
}

class SwipedelApp extends StatelessWidget {
  const SwipedelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'swipedel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AlbumsScreen(),
    );
  }
}
