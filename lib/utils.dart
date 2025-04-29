import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';

class SaveImageParams{
  final InputImage inputImage;
  final int frameIndex;
  final String? path;
  SaveImageParams(this.inputImage, this.frameIndex, this.path);
}

Future<void> saveInputImageAsFile(InputImage inputImage, int frameIndex) async {
  // Lấy thư mục tạm thời để lưu ảnh
  try {
    final directory = await getTemporaryDirectory();
    final saved = await compute(saveImage, SaveImageParams(inputImage, frameIndex, directory.path));
  } catch (e) {
    print('Error saving image: $e');
  }
}

Future<String> createTxtFile(String fileName, Directory directory) async {
  // Get the temporary directory
  final directory = await getTemporaryDirectory();
  final filePath = '${directory.path}/$fileName';
  // Create and write to the file
  final file = File(filePath);

  directory.list().forEach((element) {
    final path = element.path;
    file.writeAsString('file $path\n', mode: FileMode.append);
  });

  return file.path;
}

Uint8List? convertInputImageToBytes(InputImage inputImage) {
  img.Image? decodedImage;

  try {
    debugPrint('Image format is ${inputImage.metadata?.format ?? 'not recognized'}');

    switch (inputImage.metadata?.format) {
      case InputImageFormat.yuv_420_888: // Android
        decodedImage = decodeYUV420SP(inputImage);
        break;
      case InputImageFormat.nv21: // Android (but not used anymore from cameraX ?)
        decodedImage = decodeNV21(inputImage);
        break;
      case InputImageFormat.bgra8888: // Apple
        decodedImage = decodeBGRA8888(inputImage);
        break;
      default:
        return null;
    }
  } catch (e) {
    debugPrint('Error decoding image: $e');
    return null;
  }

  img.Image resizedImage = img.copyResize(decodedImage, width: 512);

  final Uint8List bytes = Uint8List.fromList(img.encodeJpg(resizedImage));

  return bytes;
}

// Android stuff
img.Image decodeYUV420SP(InputImage image) {
  final width = image.metadata!.size.width.toInt();
  final height = image.metadata!.size.height.toInt();

  final yuv420sp = image.bytes!;
// The math for converting YUV to RGB below assumes you're
// putting the RGB into a uint32. To simplify and keep the
// code as it is, make a 4-channel Image, get the image data bytes,
// and view it at a Uint32List. This is the equivalent to the image
// data of the 3.x version of the Image library. It does waste some
// memory, the alpha channel isn't used, but it simplifies the math.
  final outImg = img.Image(width: width, height: height, numChannels: 4);
  final outBytes = outImg.getBytes();
// View the image data as a Uint32List.
  final rgba = Uint32List.view(outBytes.buffer);

  final frameSize = width * height;

  for (var j = 0, yp = 0; j < height; j++) {
    var uvp = frameSize + (j >> 1) * width;
    var u = 0;
    var v = 0;
    for (int i = 0; i < width; i++, yp++) {
      var y = (0xff & (yuv420sp[yp])) - 16;
      if (y < 0) {
        y = 0;
      }
      if ((i & 1) == 0) {
        v = (0xff & yuv420sp[uvp++]) - 128;
        u = (0xff & yuv420sp[uvp++]) - 128;
      }

      final y1192 = 1192 * y;
      var r = (y1192 + 1634 * v);
      var g = (y1192 - 833 * v - 400 * u);
      var b = (y1192 + 2066 * u);

      if (r < 0) {
        r = 0;
      } else if (r > 262143) {
        r = 262143;
      }
      if (g < 0) {
        g = 0;
      } else if (g > 262143) {
        g = 262143;
      }
      if (b < 0) {
        b = 0;
      } else if (b > 262143) {
        b = 262143;
      }

// Write directly into the image data
      rgba[yp] = 0xff000000 | ((b << 6) & 0xff0000) | ((g >> 2) & 0xff00) | ((r >> 10) & 0xff);
    }
  }

  switch (image.metadata!.rotation) {
    case InputImageRotation.rotation0deg:
      return img.copyRotate(outImg, angle: 0);
    case InputImageRotation.rotation90deg:
      return img.copyRotate(outImg, angle: 90);
    case InputImageRotation.rotation180deg:
      return img.copyRotate(outImg, angle: 180);
    case InputImageRotation.rotation270deg:
      return img.copyRotate(outImg, angle: 270);
  }
}

// Android stuff (unused?)
img.Image decodeNV21(InputImage image) {
  final width = image.metadata!.size.width.toInt();
  final height = image.metadata!.size.height.toInt();

  final nv21 = image.bytes!;
  final outImg = img.Image(width: width, height: height, numChannels: 4);
  final outBytes = outImg.getBytes();
  final rgba = Uint32List.view(outBytes.buffer);

  final frameSize = width * height;

  for (var j = 0, yp = 0; j < height; j++) {
    var uvp = frameSize + (j >> 1) * width;
    var u = 0;
    var v = 0;
    for (int i = 0; i < width; i++, yp++) {
      var y = (0xff & (nv21[yp])) - 16;
      if (y < 0) y = 0;

      if ((i & 1) == 0) {
        v = (0xff & nv21[uvp++]) - 128;
        u = (0xff & nv21[uvp++]) - 128;
      }

      final y1192 = 1192 * y;
      var r = (y1192 + 1634 * v);
      var g = (y1192 - 833 * v - 400 * u);
      var b = (y1192 + 2066 * u);

      if (r < 0) {
        r = 0;
      } else if (r > 262143) {
        r = 262143;
      }
      if (g < 0) {
        g = 0;
      } else if (g > 262143) {
        g = 262143;
      }
      if (b < 0) {
        b = 0;
      } else if (b > 262143) {
        b = 262143;
      }

      rgba[yp] = 0xff000000 | ((b << 6) & 0xff0000) | ((g >> 2) & 0xff00) | ((r >> 10) & 0xff);
    }
  }

  switch (image.metadata!.rotation) {
    case InputImageRotation.rotation0deg:
      return img.copyRotate(outImg, angle: 0);
    case InputImageRotation.rotation90deg:
      return img.copyRotate(outImg, angle: 90);
    case InputImageRotation.rotation180deg:
      return img.copyRotate(outImg, angle: 180);
    case InputImageRotation.rotation270deg:
      return img.copyRotate(outImg, angle: 270);
  }
}

// Apple stuff
img.Image decodeBGRA8888(InputImage image) {
  final width = image.metadata!.size.width.toInt();
  final height = image.metadata!.size.height.toInt();

  final Uint8List bgra8888 = image.bytes!;
  final Uint8List rgba8888 = Uint8List(width * height * 4);

// Correcting the byte channel mapping otherwise the image has blue tint
  if (Platform.isIOS) {
    for (int i = 0, j = 0; i < bgra8888.length; i += 4, j += 4) {
      rgba8888[j] = bgra8888[i + 2]; // R <- B
      rgba8888[j + 1] = bgra8888[i + 1]; // G <- G
      rgba8888[j + 2] = bgra8888[i]; // B <- R
      rgba8888[j + 3] = bgra8888[i + 3]; // A <- A
    }
  } else {
    for (int i = 0, j = 0; i < bgra8888.length; i += 4, j += 4) {
      rgba8888[j] = bgra8888[i + 1]; // R
      rgba8888[j + 1] = bgra8888[i + 2]; // G
      rgba8888[j + 2] = bgra8888[i + 3]; // B
      rgba8888[j + 3] = bgra8888[i + 0]; // A
    }
  }

  img.Image outImg = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba8888.buffer,
    order: img.ChannelOrder.rgba,
  );

  return outImg;

// switch (image.metadata!.rotation) {
//   case InputImageRotation.rotation0deg:
//     return img.copyRotate(outImg, angle: 0);
//   case InputImageRotation.rotation90deg:
//     return img.copyRotate(outImg, angle: 90);
//   case InputImageRotation.rotation180deg:
//     return img.copyRotate(outImg, angle: 180);
//   case InputImageRotation.rotation270deg:
//     return img.copyRotate(outImg, angle: 270);
//   default:
//     return outImg; // Default case to return the image without rotation
// }
}

// Function used to convert YUV420 to NV21 because from version 0.11.0 of camera plugin
// the image returned from camera is in yuv420 format instead of nv21 (which is needed by InputImage constructor)
Uint8List convertYUV420ToNV21(CameraImage image) {
  final width = image.width;
  final height = image.height;

// Planes from CameraImage
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

// Buffers from Y, U, and V planes
  final yBuffer = yPlane.bytes;
  final uBuffer = uPlane.bytes;
  final vBuffer = vPlane.bytes;

// Total number of pixels in NV21 format
  final numPixels = width * height + (width * height ~/ 2);
  final nv21 = Uint8List(numPixels);

// Y (Luma) plane metadata
  int idY = 0;
  int idUV = width * height; // Start UV after Y plane
  final uvWidth = width ~/ 2;
  final uvHeight = height ~/ 2;

// Strides and pixel strides for Y and UV planes
  final yRowStride = yPlane.bytesPerRow;
  final yPixelStride = yPlane.bytesPerPixel ?? 1;
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 2;

// Copy Y (Luma) channel
  for (int y = 0; y < height; ++y) {
    final yOffset = y * yRowStride;
    for (int x = 0; x < width; ++x) {
      nv21[idY++] = yBuffer[yOffset + x * yPixelStride];
    }
  }

// Copy UV (Chroma) channels in NV21 format (YYYYVU interleaved)
  for (int y = 0; y < uvHeight; ++y) {
    final uvOffset = y * uvRowStride;
    for (int x = 0; x < uvWidth; ++x) {
      final bufferIndex = uvOffset + (x * uvPixelStride);
      nv21[idUV++] = vBuffer[bufferIndex]; // V channel
      nv21[idUV++] = uBuffer[bufferIndex]; // U channel
    }
  }

  return nv21;
}

Uint8List? resizeBinaryImage({
  required Uint8List imageData,
  int? maxWidth,
  int? maxHeight,
}) {
  if (maxWidth == null && maxHeight == null) {
    return null;
  }

  img.Image? originalImage = img.decodeImage(imageData);

  if (originalImage == null) {
    debugPrint('Could not decode image');
    return null;
  }

  double aspectRatio = originalImage.width / originalImage.height;
  int newWidth;
  int newHeight;

  if (maxWidth != null && maxHeight == null) {
    newWidth = maxWidth;
    newHeight = (maxWidth / aspectRatio).round();
  } else if (maxWidth == null && maxHeight != null) {
    newHeight = maxHeight;
    newWidth = (maxHeight * aspectRatio).round();
  } else {
    newWidth = maxWidth!;
    newHeight = maxHeight!;
  }

  img.Image resizedImage = img.copyResize(
    originalImage,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.average,
  );

  return img.encodeJpg(resizedImage);
}

Future<String?> convertImageToBase64(Image image) async {
  try {
// Step 1: Convert the image to an ImageProvider (assuming AssetImage or NetworkImage)
    final ImageProvider imageProvider = image.image;

// Step 2: Resolve the image and obtain a ImageStream
    final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
    final Completer<ui.Image> completer = Completer<ui.Image>();

// Step 3: Add a listener to get the image once it is available
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    }));

// Step 4: Wait for the image to be loaded
    final ui.Image loadedImage = await completer.future;

// Step 5: Convert the ui.Image to byte data
    final ByteData? byteData = await loadedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
// Step 6: Convert the byte data to Uint8List
      final Uint8List uint8List = byteData.buffer.asUint8List();

// Step 7: Convert the Uint8List to Base64 string
      String base64String = base64Encode(uint8List);

      return base64String;
    }
  } catch (e) {
    debugPrint('Error converting image to base64: $e');
  }
  return null;
}

Future<Uint8List?> convertImageToBytes(Image image) async {
// Create a Completer to handle asynchronous image loading
  final Completer<ui.Image> completer = Completer<ui.Image>();

// Start loading the image
  final ImageStream imageStream = image.image.resolve(const ImageConfiguration());

// Attach a one-time listener to the imageStream
  imageStream.addListener(
    ImageStreamListener((ImageInfo info, bool _) {
// Complete the Completer with the loaded image
      completer.complete(info.image);
    }),
  );

// Wait for the image to be fully loaded
  final ui.Image uiImage = await completer.future;

  final ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    throw Exception('Failed to convert image to byte data');
  }

  final Uint8List bytes = byteData.buffer.asUint8List();

  return bytes;
}

Future<bool> saveImage(SaveImageParams params) async {
  final frameIndex = params.frameIndex;
  final inputImage = params.inputImage;
  final path = params.path;

  // final directory = await getTemporaryDirectory();
  // final filePath = '${directory.path}/frame_${frameIndex.toString().padLeft(5, '0')}.jpg';
  final filePath = '${path}/frame_${frameIndex.toString().padLeft(5, '0')}.jpg';
  img.Image? decodedImage;
  try {
    // debugPrint('Image format is ${inputImage.metadata?.format ?? 'not recognized'}');

    switch (inputImage.metadata?.format) {
      case InputImageFormat.yuv_420_888:
        decodedImage = decodeYUV420SP(inputImage);
        break;
      case InputImageFormat.bgra8888:
        decodedImage = decodeBGRA8888(inputImage);
        break;
      case InputImageFormat.nv21:
        decodedImage = decodeNV21(inputImage);
        break;
      default:
        return false;
    }
  } catch (e) {
    // debugPrint('Error decoding image: $e');
    return false;
  }

  img.Image resizedImage = img.copyResize(decodedImage, width: 512);
  final bool saved = await img.encodeJpgFile(filePath, resizedImage);

  // debugPrint('Image saved: $saved with path: $filePath');

  return saved;
}

Future<String?> resizeImageFile({
  required String imagePath,
  int? maxWidth,
  int? maxHeight,
}) async {
  if (maxWidth == null && maxHeight == null) {
    return null;
  }

  Uint8List imageBytes = await File(imagePath).readAsBytes();
  img.Image? originalImage = img.decodeImage(imageBytes);

  if (originalImage == null) {
    debugPrint('Could not decode image');
    return null;
  }

  double aspectRatio = originalImage.width / originalImage.height;
  int newWidth;
  int newHeight;

  if (maxWidth != null && maxHeight == null) {
    newWidth = maxWidth;
    newHeight = (maxWidth / aspectRatio).round();
  } else if (maxWidth == null && maxHeight != null) {
    newHeight = maxHeight;
    newWidth = (maxHeight * aspectRatio).round();
  } else {
    newWidth = maxWidth!;
    newHeight = maxHeight!;
  }

  img.Image resizedImage = img.copyResize(
    originalImage,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.average,
  );

  final tempDir = await getTemporaryDirectory();
  final targetPath = join(tempDir.path, 'resized_avatar.jpg');

  File resizedFile = File(targetPath);
  resizedFile.writeAsBytes(img.encodeJpg(resizedImage));
  return resizedFile.path;
}
