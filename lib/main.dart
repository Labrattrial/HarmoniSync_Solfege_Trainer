import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(home: PitchDetectorScreen()));
}

class PitchDetectorScreen extends StatefulWidget {
  const PitchDetectorScreen({super.key});

  @override
  State<PitchDetectorScreen> createState() => _PitchDetectorScreenState();
}

class _PitchDetectorScreenState extends State<PitchDetectorScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  StreamSubscription<Uint8List>? _audioStreamSub;
  double? _detectedPitch;
  Timer? _throttle;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
  }

  void _startStopRecording() async {
    if (_isRecording) {
      await _audioStreamSub?.cancel();
      await _recorder.stopRecorder();
      setState(() => _isRecording = false);
    } else {
      final audioStreamController = StreamController<Uint8List>();

      await _recorder.startRecorder(
        toStream: audioStreamController.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 44100,
      );

      _audioStreamSub = audioStreamController.stream.listen((data) {
        if (_throttle?.isActive ?? false) return;

        _yinPitchDetection(data, 44100, 1);
        _throttle = Timer(const Duration(milliseconds: 100), () {});
      });

      setState(() => _isRecording = true);
    }
  }

  void _yinPitchDetection(Uint8List audioData, int sampleRate, int channelCount) {
    final length = audioData.length ~/ 2;
    if (length < 2) return;

    final Float64List audioBuffer = Float64List(length);
    final ByteData byteData = ByteData.sublistView(audioData);

    for (int i = 0; i < length; i++) {
      final int sample = byteData.getInt16(i * 2, Endian.little);
      audioBuffer[i] = sample / 32768.0;
    }

    final double threshold = 0.10;
    final int bufferSize = audioBuffer.length;
    final int maxLag = bufferSize ~/ 2;
    final Float64List difference = Float64List(maxLag);

    for (int lag = 1; lag < maxLag; lag++) {
      double sum = 0;
      for (int i = 0; i < maxLag; i++) {
        final double delta = audioBuffer[i] - audioBuffer[i + lag];
        sum += delta * delta;
      }
      difference[lag] = sum;
    }

    final Float64List cmndf = Float64List(maxLag);
    cmndf[0] = 1;
    double runningSum = 0;

    for (int tau = 1; tau < maxLag; tau++) {
      runningSum += difference[tau];
      cmndf[tau] = difference[tau] / ((runningSum / tau) + 1e-6);
    }

    int tauEstimate = -1;
    for (int tau = 2; tau < maxLag - 1; tau++) {
      if (cmndf[tau] < threshold &&
          cmndf[tau] < cmndf[tau - 1] &&
          cmndf[tau] <= cmndf[tau + 1]) {
        tauEstimate = tau;
        break;
      }
    }

    if (tauEstimate != -1) {
      double pitch = sampleRate / tauEstimate;
      setState(() => _detectedPitch = pitch);
    } else {
      setState(() => _detectedPitch = null);
    }
  }

  @override
  void dispose() {
    _audioStreamSub?.cancel();
    _recorder.closeRecorder();
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pitch Detector")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _detectedPitch != null
                  ? "Detected Pitch: ${_detectedPitch!.toStringAsFixed(2)} Hz"
                  : "No pitch detected",
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startStopRecording,
              child: Text(_isRecording ? "Stop" : "Start"),
            ),
          ],
        ),
      ),
    );
  }
}
