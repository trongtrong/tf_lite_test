import 'dart:collection';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../utils.dart';
import 'camera_view.dart';
import 'painters/object_detector_painter.dart';

enum TypeTrain {
  int8,
  float16,
  float32,
}

class ObjectDetectorView extends StatefulWidget {
  final TypeTrain typeTrain;

  const ObjectDetectorView({super.key, this.typeTrain = TypeTrain.int8});

  @override
  State<ObjectDetectorView> createState() => _ObjectDetectorView();
}

class _ObjectDetectorView extends State<ObjectDetectorView> {
  late ObjectDetector _objectDetector;
  bool _canProcess = false;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  int index = 0;
  final Queue<SaveImageParams> frameQueue = Queue<SaveImageParams>();

  @override
  void initState() {
    super.initState();

    _initializeDetector(DetectionMode.stream);
  }

  @override
  void dispose() {
    _canProcess = false;
    _objectDetector.close();
    index = 0;
    frameQueue.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraView(
      title: 'Object Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: (inputImage) async {
        frameQueue.add(SaveImageParams(inputImage, index, null));
        // saveInputImageAsFile(inputImage, index);
        index++;
        processImage(inputImage);
      },
      onScreenModeChanged: _onScreenModeChanged,
      initialDirection: CameraLensDirection.back,
      onStop: () async {
        //pop screen
        // Navigator.pop(context);

        //while frameque and create max 5 isolate to process save file from param in framque



        // final cmd = <String>[];
        //ffmpeg -framerate 30 -i image%04d.jpg -c:v libx264 -r 30 -pix_fmt yuv420p output_video.mp4
        // cmd.add("-framerate");
        // cmd.add('30');
        // cmd.add('-i');
        // final directory = await getTemporaryDirectory();
        // cmd.add('${directory.path}/frame_%05d.jpg');

        // await directory.list().forEach((element) {
        // });
        // cmd.add('-c:v');
        // cmd.add('mpeg4');
        // cmd.add('-r');
        // cmd.add('30');
        // cmd.add('-safe');
        // cmd.add('0');
        // cmd.add('${directory.path}/output.mp4');

        // print('cmd ==        $cmd');

        // FFmpegKit.executeWithArgumentsAsync(
        //   cmd,
        //   (session) {
        //     if (session.getReturnCode() == 0) {
        //       print('Video created');
        //     } else {}
        //   },
        //   (log) {
        //     print('log ===   ${log.getMessage()}');
        //   },
        //   (statistics) {},
        // );
      },
    );
  }

  void _onScreenModeChanged(ScreenMode mode) {
    switch (mode) {
      case ScreenMode.gallery:
        _initializeDetector(DetectionMode.single);
        return;

      case ScreenMode.liveFeed:
        _initializeDetector(DetectionMode.stream);
        return;
    }
  }

  void _initializeDetector(DetectionMode mode) async {
    print('Set detector in mode: $mode');

    // uncomment next lines if you want to use the default model
    // final options = ObjectDetectorOptions(
    //     mode: mode,
    //     classifyObjects: true,
    //     multipleObjects: true);
    // _objectDetector = ObjectDetector(options: options);

    // uncomment next lines if you want to use a local model
    // make sure to add tflite model to assets/ml
    String path = 'assets/football_detection_model.tflite';
    if (widget.typeTrain == TypeTrain.float32) {
      path = 'assets/best_float32.tflite';
    } else if (widget.typeTrain == TypeTrain.float16) {
      path = 'assets/best_float16.tflite';
    }
    final modelPath = await getModelPath(path);
    final options = LocalObjectDetectorOptions(
      mode: mode,
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);

    // uncomment next lines if you want to use a remote model
    // make sure to add model to firebase
    // final modelName = 'bird-classifier';
    // final response =
    //     await FirebaseObjectDetectorModelManager().downloadModel(modelName);
    // print('Downloaded: $response');
    // final options = FirebaseObjectDetectorOptions(
    //   mode: mode,
    //   modelName: modelName,
    //   classifyObjects: true,
    //   multipleObjects: true,
    // );
    // _objectDetector = ObjectDetector(options: options);

    _canProcess = true;
  }

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final objects = await _objectDetector.processImage(inputImage);
    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final painter = ObjectDetectorPainter(objects, inputImage.metadata!.rotation, inputImage.metadata!.size);
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Objects found: ${objects.length}\n\n';
      for (final object in objects) {
        text += 'Object:  trackingId: ${object.trackingId} - ${object.labels.map((e) => e.text)}\n\n';
      }
      _text = text;
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> getModelPath(String asset) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$asset';
    await Directory(dirname(path)).create(recursive: true);
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(asset);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }
}
