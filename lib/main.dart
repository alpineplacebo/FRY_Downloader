import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the flutter_rust_bridge native library.
  await RustLib.init();

  runApp(
    const ProviderScope(
      child: FryDownloaderApp(),
    ),
  );
}
