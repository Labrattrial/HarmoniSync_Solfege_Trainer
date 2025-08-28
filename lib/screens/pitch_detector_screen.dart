import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/note_utils.dart';
import '../widgets/score_sheet_widget.dart';

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
  String? _detectedNote;
  Timer? _throttle;
  int _currentNoteIndex = 0;
  bool _hasMatched = false;

  final solfegeFrequencies = [
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5',
  ];

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
      setState(() {
        _isRecording = false;
        _detectedPitch = null;
        _detectedNote = null;
        _currentNoteIndex = 0;
        _hasMatched = false;
      });
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

      setState(() {
        _isRecording = true;
        _detectedPitch = null;
        _detectedNote = null;
        _currentNoteIndex = 0;
        _hasMatched = false;
      });
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
      String detected = NoteUtils.frequencyToNote(pitch);

      setState(() {
        _detectedPitch = pitch;
        _detectedNote = detected;

        if (!_hasMatched &&
            detected == NoteUtils.frequencyToNote(
              NoteUtils.noteFrequencies[solfegeFrequencies[_currentNoteIndex]]!,
            )) {
          _hasMatched = true;
          Future.delayed(const Duration(milliseconds: 600), () {
            setState(() {
              if (_currentNoteIndex < solfegeFrequencies.length - 1) {
                _currentNoteIndex++;
                _hasMatched = false;
              }
            });
          });
        }
      });
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Solfege Pitch Trainer"),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.9, -0.8),
            end: Alignment(1.0, 0.9),
            colors: [
              Color(0xFFFFF9C4),
              Color(0xFFFFECB3),
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          _detectedPitch != null
                              ? "🎵 Pitch: ${_detectedPitch!.toStringAsFixed(2)} Hz\n🎶 Note: $_detectedNote"
                              : "Press start to begin",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isLandscape ? 20 : 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ScoreSheetWidget(
                          detectedNote: _isRecording ? _detectedNote : null,
                          currentIndex: _isRecording ? _currentNoteIndex : -1,
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _startStopRecording,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isLandscape ? 40 : 24,
                              vertical: isLandscape ? 20 : 16,
                            ),
                            textStyle: TextStyle(
                              fontSize: isLandscape ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: Text(_isRecording ? "⏹ Stop" : "🎙 Start"),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}