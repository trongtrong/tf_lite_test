import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:object_detection_mlkit/screens/facedetection.dart';
import 'package:object_detection_mlkit/screens/object.dart';
List<CameraDescription> cameras = [];
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML_KIT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ObjectDetectorView(),
    );
  }
}


