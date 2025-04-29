
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

final Queue<Uint8List> frameQueue = Queue<Uint8List>();

// Số lượng Isolate tối đa
const int maxIsolates = 5;

// Danh sách các Isolate đang hoạt động
final List<Isolate> activeIsolates = [];

// Hàm xử lý frame trong Isolate
Future<void> processFrame(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is Map<String, dynamic>) {
      final Uint8List frame = message['frame'];
      final int frameIndex = message['frameIndex'];
      final SendPort replyPort = message['replyPort'];

      // Xử lý frame (ví dụ: lưu thành file)
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/frame_${frameIndex.toString().padLeft(5, '0')}.jpg';

      final img.Image? decodedImage = img.decodeImage(frame);
      if (decodedImage != null) {
        final resizedImage = img.copyResize(decodedImage, width: 512);
        final file = File(filePath);
        await file.writeAsBytes(img.encodeJpg(resizedImage));
        print('Frame $frameIndex saved at $filePath');
      }

      // Gửi tín hiệu hoàn thành
      replyPort.send(true);
    }
  }
}
