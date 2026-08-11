import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/editor_state.dart';
import 'components/editor_sidebar.dart';
import 'components/level_gallery_view.dart';
import 'dialogs/single_level_editor_dialog.dart';
import 'dialogs/bulk_generator_dialog.dart';
import '../../data/level_binary_codec.dart';
import '../../data/models/level.dart';

class LevelEditorApp extends StatelessWidget {
  const LevelEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorState(),
      child: MaterialApp(
        title: 'Arrow Escape Level Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0B0D12),
          primaryColor: Colors.indigoAccent,
          colorScheme: const ColorScheme.dark(
            primary: Colors.indigoAccent,
            surface: Color(0xFF141720),
          ),
        ),
        home: const LevelEditorHomeScreen(),
      ),
    );
  }
}

class LevelEditorHomeScreen extends StatefulWidget {
  const LevelEditorHomeScreen({super.key});

  @override
  State<LevelEditorHomeScreen> createState() => _LevelEditorHomeScreenState();
}

class _LevelEditorHomeScreenState extends State<LevelEditorHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultAssets();
    });
  }

  Future<void> _loadDefaultAssets() async {
    try {
      final bytes = await rootBundle.load('assets/levels.bin');
      final uint8 = bytes.buffer.asUint8List();
      final decoder = LevelBinaryDecoder.fromBytes(uint8);
      final levels = decoder.decodeAll();
      if (mounted) {
        context.read<EditorState>().setLevels(levels);
      }
    } catch (_) {
      // Asset not found or decoding failed silently on fresh startup
    }
  }

  void _openSingleLevelEditor(BuildContext context, LevelModel level) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SingleLevelEditorDialog(
        initialLevel: level,
        onSave: (updated) {
          context.read<EditorState>().updateSelectedLevel(updated);
        },
      ),
    );
  }

  void _openBulkGenerator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BulkGeneratorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Navigation & Tool Sidebar
          EditorSidebar(
            onOpenBulkGenerator: () => _openBulkGenerator(context),
          ),

          // Right Workspace & Level Gallery Grid
          Expanded(
            child: LevelGalleryView(
              onEditLevel: (level) => _openSingleLevelEditor(context, level),
            ),
          ),
        ],
      ),
    );
  }
}
