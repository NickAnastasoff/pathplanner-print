import 'package:flutter/material.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class AutoEditorPage extends StatefulWidget {
  final SharedPreferences prefs;
  final PathPlannerAuto auto;
  final List<PathPlannerPath> allPaths;
  final List<ChoreoPath> allChoreoPaths;
  final List<String> allPathNames;
  final FieldImage fieldImage;
  final ValueChanged<String> onRenamed;
  final ChangeStack undoStack;
  final bool shortcuts;
  final PPLibTelemetry? telemetry;
  final bool hotReload;

  const AutoEditorPage({
    super.key,
    required this.prefs,
    required this.auto,
    required this.allPaths,
    required this.allChoreoPaths,
    required this.allPathNames,
    required this.fieldImage,
    required this.onRenamed,
    required this.undoStack,
    this.shortcuts = true,
    this.telemetry,
    this.hotReload = false,
  });

  @override
  State<AutoEditorPage> createState() => _AutoEditorPageState();
}

class _AutoEditorPageState extends State<AutoEditorPage> {
  final GlobalKey _tempBoundaryKey = GlobalKey();

  Future<Uint8List> _captureFieldImagePng() async {
    try {
      RenderRepaintBoundary boundary = _tempBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print(e);
      throw e;
    }
  }

  // Function to save field image as PNG
  Future<void> _saveFieldImage() async {
    // Use FilePicker to ask the user where to save the image
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: '${widget.auto.name}.png',
    );

    if (outputFile != null) {
      try {
        // Show field image in full screen
        await showDialog(
          context: context,
          builder: (context) {
            return Scaffold(
                backgroundColor: Colors.black.withOpacity(0.8),
                body: Stack(children: [
                  Center(
                    child: RepaintBoundary(
                      key: _tempBoundaryKey,
                      child: widget.fieldImage.getWidget(),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 40,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ]));
          },
        );

        Uint8List pngBytes = await _captureFieldImagePng();

        final imageFile = File(outputFile);
        await imageFile.writeAsBytes(pngBytes);

        // Show a message that the file has been saved
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved to $outputFile')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    List<String> autoPathNames = widget.auto.getAllPathNames();
    List<PathPlannerPath> autoPaths = widget.auto.choreoAuto
        ? []
        : autoPathNames
            .map((name) =>
                widget.allPaths.firstWhere((path) => path.name == name))
            .toList();
    List<ChoreoPath> autoChoreoPaths = widget.auto.choreoAuto
        ? autoPathNames
            .map((name) =>
                widget.allChoreoPaths.firstWhere((path) => path.name == name))
            .toList()
        : [];

    final editorWidget = SplitAutoEditor(
      prefs: widget.prefs,
      auto: widget.auto,
      autoPaths: autoPaths,
      autoChoreoPaths: autoChoreoPaths,
      allPathNames: widget.allPathNames,
      fieldImage: widget.fieldImage,
      undoStack: widget.undoStack,
      onAutoChanged: () {
        setState(() {
          if (widget.auto.choreoAuto) {
            var pathNames = widget.auto.getAllPathNames();
            if (pathNames.isNotEmpty) {
              ChoreoPath first = widget.allChoreoPaths
                  .firstWhere((e) => e.name == pathNames.first);
              if (first.trajectory.states.isNotEmpty) {
                Pose2d startPose = Pose2d(
                  position: first.trajectory.states.first.position,
                  rotation: GeometryUtil.toDegrees(
                      first.trajectory.states.first.holonomicRotationRadians),
                );
                widget.auto.startingPose = startPose;
              }
            }
          }

          widget.auto.saveFile();
        });

        if (widget.hotReload) {
          widget.telemetry?.hotReloadAuto(widget.auto);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveFieldImage,
            ),
            SizedBox(width: 8), // spacing between the button and title
            RenamableTitle(
              title: widget.auto.name,
              textStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              onRename: (value) {
                widget.onRenamed.call(value);
                setState(() {});
              },
            ),
          ],
        ),
        leading: BackButton(
          onPressed: () {
            widget.undoStack.clearHistory();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ConditionalWidget(
        condition: widget.shortcuts,
        trueChild: KeyBoardShortcuts(
          keysToPress: shortCut(BasicShortCuts.undo),
          onKeysPressed: widget.undoStack.undo,
          child: KeyBoardShortcuts(
            keysToPress: shortCut(BasicShortCuts.redo),
            onKeysPressed: widget.undoStack.redo,
            child: editorWidget,
          ),
        ),
        falseChild: editorWidget,
      ),
    );
  }
}
