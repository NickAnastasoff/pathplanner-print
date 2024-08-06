import 'package:flutter/material.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/geometry_util.dart';
import 'package:pathplanner/util/pose2d.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:pathplanner/util/export_auto_png.dart';
import 'package:pathplanner/widgets/editor/split_auto_editor.dart';

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
  final GlobalKey _fieldImageKey = GlobalKey();

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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () => exportAutoPng(
                context,
                widget.fieldImage,
                widget.auto.name,
                _fieldImageKey,
                autoPaths,
                autoChoreoPaths,
                widget.prefs,
              ),
            ),
            SizedBox(width: 8),
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
      body: SplitAutoEditor(
        key: _fieldImageKey,
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
      ),
    );
  }
}
