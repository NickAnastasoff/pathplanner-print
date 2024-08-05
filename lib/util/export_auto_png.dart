import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

Future<Uint8List> _captureFieldImagePng(GlobalKey boundaryKey) async {
  try {
    RenderRepaintBoundary boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  } catch (e) {
    print(e);
    throw e;
  }
}

// Function to save field image as PNG
Future<void> exportAutoPng(BuildContext context, FieldImage fieldImage,
    String autoName, GlobalKey tempBoundaryKey) async {
  // Use FilePicker to ask the user where to save the image
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Please select an output file:',
    fileName: '$autoName.png',
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
                    key: tempBoundaryKey,
                    child: Container(
                      color: Colors.white,
                      child: fieldImage.getWidget(),
                    ),
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

      Uint8List pngBytes = await _captureFieldImagePng(tempBoundaryKey);

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
