import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Note: Web-only APIs removed per requirement. Using native/audio package paths only.
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/music_service.dart';
import '../services/yin_algorithm.dart';
import '../utils/note_utils.dart';
import '../widgets/music_sheet.dart';
import '../database/database_helper.dart';

class ExerciseScreen extends StatefulWidget {
  final String level;

  const ExerciseScreen({
    super.key,
    required this.level,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with SingleTickerProviderStateMixin {
  late Future<Score> _scoreFuture;
  bool _isLoading = true;
  String? _error;
  bool _isPlaying = false;
  bool _isPaused = false;
  int _countdown = 3;
  bool _showCountdown = false;
  Timer? _countdownTimer;
  Timer? _playbackTimer;
  Timer? _metronomeTimer;
  Timer? _pitchDetectionTimer;
  double _currentTime = 0.0;
  double _totalDuration = 0.0;
  bool _reachedEnd = false;
  double _lastMeasurePosition = 1;
  int _currentNoteIndex = 0;
  Stopwatch? _playbackStopwatch;
  double _elapsedBeforePauseSec = 0.0;
  int _totalPlayableNotes = 0;
  int _correctNotesCount = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _glowColorAnimation;
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _metronomePlayer;
  String? _currentDetectedNote;
  String? _expectedNote;
  bool _isCorrect = false;
  StreamSubscription? _audioStreamSubscription;
  StreamController<Uint8List>? _audioStreamController;
  double _bpm = 120.0; // Default BPM
  final ScrollController _noteScrollController = ScrollController();
  final Map<int, bool> _noteCorrectness = {};
  bool _metronomeEnabled = false;
  bool _metronomeFlash = false;
  int _metronomeBeatIndex = 0;
  int? _timeSigBeats;
  int? _timeSigBeatType;
  int _lastWholeBeat = -1;
  // Metronome click timing control
  int _lastClickStartUs = 0;
  static const int _clickDurationMs = 50;
  // Web Audio unlock not used on non-web platforms

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadScore();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.green.withOpacity(0.5),
    ).animate(_pulseController);

    _recorder = FlutterSoundRecorder();
    _initializeRecorder();
    _metronomePlayer = FlutterSoundPlayer();
    _initializeMetronomePlayer();
    
    // Ensure initial BPM is within valid range
    _bpm = _bpm.clamp(40.0, 244.0);
  }

  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
    await _recorder.openRecorder();
    try {
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 60));
    } catch (_) {}
  }

  Future<void> _initializeMetronomePlayer() async {
    try {
      await _metronomePlayer.openPlayer();
    } catch (e) {
      // Fallback silently if player cannot open
      print('Error opening metronome player: $e');
    }
  }

  Future<void> _unlockWebAudioIfNeeded() async { return; }

  void _startPitchDetection() async {
    try {
      // Avoid multiple starts
      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
      } catch (_) {}

      _audioStreamController = StreamController<Uint8List>();
      
      await _recorder.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 44100,
      );

      // Throttle heavy pitch detection work
      Timer? _throttleTimer;
      _audioStreamSubscription = _audioStreamController!.stream.listen((buffer) {
        if (!_isPlaying) return;

        try {
          if (_throttleTimer?.isActive ?? false) return;
          _throttleTimer = Timer(const Duration(milliseconds: 80), () {});

          final frequency = YinAlgorithm.detectPitch(buffer, 44100);
          if (frequency == null) return;
          final note = NoteUtils.frequencyToNote(frequency);
          if (!mounted) return;
          setState(() {
            _currentDetectedNote = note;
            if (_expectedNote != null) {
              _isCorrect = note == _expectedNote;
              final bool? previous = _noteCorrectness[_currentNoteIndex];
              _noteCorrectness[_currentNoteIndex] = _isCorrect;
              if (_isCorrect && previous != true) {
                _correctNotesCount++;
              }
              _glowColorAnimation = ColorTween(
                begin: Colors.transparent,
                end: _isCorrect 
                  ? Colors.green.withOpacity(0.5)
                  : Colors.red.withOpacity(0.5),
              ).animate(_pulseController);
            }
          });
        } catch (e) {
          print('Error in pitch detection: $e');
        }
      });
    } catch (e) {
      print('Error starting recorder: $e');
    }
  }

  void _stopPitchDetection() async {
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _audioStreamController?.close();
    _audioStreamController = null;
    try {
      await _recorder.stopRecorder();
    } catch (e) {
      print('Error stopping recorder: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playbackTimer?.cancel();
    _metronomeTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _audioStreamController?.close();
    _pulseController.dispose();
    _recorder.closeRecorder();
    _metronomePlayer.closePlayer();
    _noteScrollController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadScore() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final score = await MusicService.loadMusicXML(widget.level);
      setState(() {
        _scoreFuture = Future.value(score);
        _isLoading = false;
        _timeSigBeats = score.beats;
        _timeSigBeatType = score.beatType;
        // Count playable (non-rest) notes for scoring
        _totalPlayableNotes = 0;
        for (final m in score.measures) {
          for (final n in m.notes) {
            if (!n.isRest) _totalPlayableNotes++;
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load exercise: $e';
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    // Cancel any existing timers
    _playbackTimer?.cancel();
    _countdownTimer?.cancel();
    
    setState(() {
      _countdown = 3;
      _isPlaying = false;
      _isPaused = false;
      _currentTime = 0.0;
      _showCountdown = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdown = 0;
          _showCountdown = false;
          _countdownTimer?.cancel();
          _startExercise();
        }
      });
    });
  }

  void _showSettingsDialog() {
    double tempBpm = _bpm; // Temporary variable to hold BPM value during slider changes
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: AlertDialog(
                backgroundColor: const Color(0xFF232B39),
                title: const Text(
                  'Note Speed Settings',
                  style: TextStyle(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                          onPressed: () {
                            if (tempBpm > 40) {
                              tempBpm = (tempBpm - 1).clamp(40.0, 244.0);
                              setDialogState(() {}); // Update dialog state
                              if (mounted) {
                                setState(() {
                                  _bpm = tempBpm;
                                  if (_metronomeEnabled) {
                                    _startMetronome();
                                  }
                                  // Restart exercise with new BPM if currently playing
                                  if (_isPlaying) {
                                    _stopExercise();
                                    _startExercise();
                                  }
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${tempBpm.round()} BPM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          onPressed: () {
                            if (tempBpm < 244) {
                              tempBpm = (tempBpm + 1).clamp(40.0, 244.0);
                              setDialogState(() {}); // Update dialog state
                              if (mounted) {
                                setState(() {
                                  _bpm = tempBpm;
                                  if (_metronomeEnabled) {
                                    _startMetronome();
                                  }
                                  // Restart exercise with new BPM if currently playing
                                  if (_isPlaying) {
                                    _stopExercise();
                                    _startExercise();
                                  }
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Colors.blue.withOpacity(0.2),
                        thumbColor: Colors.white,
                        overlayColor: Colors.blue.withOpacity(0.2),
                        valueIndicatorColor: Colors.blue,
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12.0,
                          elevation: 4.0,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 24.0,
                        ),
                      ),
                      child: Slider(
                        value: tempBpm,
                        min: 40,
                        max: 244,
                        divisions: 204,
                        label: '${tempBpm.round()} BPM',
                        onChanged: (value) {
                          tempBpm = value;
                          setDialogState(() {}); // Update dialog state
                          if (mounted) {
                            setState(() {
                              _bpm = value;
                              if (_metronomeEnabled) {
                                _startMetronome();
                              }
                              // Restart exercise with new BPM if currently playing
                              if (_isPlaying) {
                                _stopExercise();
                                _startExercise();
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '40 BPM',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '244 BPM',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Higher BPM = Faster Note Changes',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _bpm = tempBpm;
                          if (_metronomeEnabled) {
                            _startMetronome();
                          }
                          // Restart exercise with new BPM if currently playing
                          if (_isPlaying) {
                            _stopExercise();
                            _startExercise();
                          }
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startExercise() {
    if (!mounted) return;
    
    // Cancel any existing timers
    _playbackTimer?.cancel();
    
    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _reachedEnd = false;
      _currentTime = 0.0;
      _currentNoteIndex = 0;
      _noteCorrectness.clear(); // Clear the correctness history when starting
      _correctNotesCount = 0;
    });

    // Reset precise timing
    _elapsedBeforePauseSec = 0.0;
    _playbackStopwatch?.stop();
    _playbackStopwatch = Stopwatch()..start();

    // Ensure the first expected note is set at start
    _scoreFuture.then((score) {
      if (!mounted) return;
      _updateExpectedNote(score);
    });

    // Start pitch detection
    _startPitchDetection();

    // Start metronome if enabled
    if (_metronomeEnabled) {
      _lastWholeBeat = -1; // realign to next detected beat
    }

    // Get the score from the future
    _scoreFuture.then((score) {
      if (!mounted) return;
      
      // Start playback timer with dynamic BPM
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        setState(() {
          if (!_reachedEnd) {
            final double stopwatchSec = (_playbackStopwatch?.elapsedMicroseconds ?? 0) / 1e6;
            _currentTime = _elapsedBeforePauseSec + stopwatchSec;
            
            // Calculate note duration based on current BPM
            const double secondsPerMinute = 60.0;
            final double noteDuration = secondsPerMinute / _bpm;
            
            // Calculate total beats up to current time (used by metronome and note selection)
            final double metronomeBeatUnitSec = (60.0 / _bpm) * (4.0 / (_timeSigBeatType?.toDouble() ?? 4.0));
            final double currentBeats = _currentTime / metronomeBeatUnitSec;

            // End-of-sheet handling
            if (_currentTime >= _lastMeasurePosition) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
              _stopPitchDetection();
              _stopMetronome();
              // Show completion summary
              _showCompletionDialog();
              return; // short-circuit to avoid any triggers in this tick
            } else {
              // Metronome: trigger on every beat (catch up if timer skipped)
              if (_metronomeEnabled) {
                final int targetBeat = currentBeats.floor();
                const double clickDurationSec = 0.05; // 50ms
                while (_lastWholeBeat < targetBeat) {
                  _lastWholeBeat++;
                  final int beatsPerMeasure = (_timeSigBeats ?? 4).clamp(1, 12);
                  final bool isDownbeat = (_lastWholeBeat % beatsPerMeasure) == 0;
                  final double beatStartSec = _lastWholeBeat * metronomeBeatUnitSec;
                  if (beatStartSec + clickDurationSec <= _lastMeasurePosition) {
                    _triggerMetronome(downbeat: isDownbeat);
                  } else {
                    break; // don't schedule beyond end
                  }
                }
              }
            }
            
            // Find the current note based on beats
            double totalBeats = 0.0;
            int newNoteIndex = 0;
            bool foundNote = false;
            
            for (final measure in score.measures) {
              for (final note in measure.notes) {
                if (!note.isRest) {
                  if (currentBeats >= totalBeats && currentBeats < totalBeats + _getNoteDuration(note)) {
                    foundNote = true;
                    break;
                  }
                  newNoteIndex++;
                }
                totalBeats += _getNoteDuration(note);
              }
              if (foundNote) break;
            }
            
            // Update expected/current note on index change or if not set yet (first note)
            if (newNoteIndex != _currentNoteIndex || _expectedNote == null) {
              _currentNoteIndex = newNoteIndex;
              _updateExpectedNote(score);
            }
            
            // Stop if we've reached the end of the sheet
            if (_currentTime >= _lastMeasurePosition) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
              _stopPitchDetection();
              _stopMetronome();
            }
          }
        });
      });
    });
  }

  // Helper method to get note duration in beats
  double _getNoteDuration(Note note) {
    switch (note.type) {
      case 'whole':
        return 4.0;
      case 'half':
        return 2.0;
      case 'quarter':
        return 1.0;
      case 'eighth':
        return 0.5;
      case '16th':
        return 0.25;
      default:
        return 1.0; // Default to quarter note duration
    }
  }

  void _scrollToCurrentNote() {
    if (!_noteScrollController.hasClients) return;
    
    // Calculate the position to scroll to
    final itemWidth = 100.0; // Approximate width of each note item including padding
    final screenWidth = MediaQuery.of(context).size.width;
    final targetPosition = _currentNoteIndex * itemWidth - (screenWidth / 2) + (itemWidth / 2);
    
    // Animate to the target position
    _noteScrollController.animateTo(
      targetPosition.clamp(0.0, _noteScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _updateExpectedNote(Score score) {
    // Find the current note in the score
    int totalNotes = 0;
    for (final measure in score.measures) {
      for (final note in measure.notes) {
        if (totalNotes == _currentNoteIndex && !note.isRest) {
          setState(() {
            _expectedNote = "${note.step}${note.octave}";
            _isCorrect = false;
            // Don't update _noteCorrectness here, only when we get a correct/incorrect result
          });
          _scrollToCurrentNote(); // Scroll to keep current note visible
          return;
        }
        if (!note.isRest) {
          totalNotes++;
        }
      }
    }
    setState(() {
      _expectedNote = null;
      _isCorrect = false;
    });
  }

  void _pauseExercise() {
    // Cancel the playback timer
    _playbackTimer?.cancel();
    _playbackTimer = null;
    
    // Stop pitch detection
    _stopPitchDetection();
    _stopMetronome(immediate: true);
    // Accumulate elapsed time and stop stopwatch
    final double stopwatchSec = (_playbackStopwatch?.elapsedMicroseconds ?? 0) / 1e6;
    _elapsedBeforePauseSec += stopwatchSec;
    _playbackStopwatch?.stop();
    
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  void _resumeExercise() {
    if (!mounted) return;
    
    // Ensure no existing timer is running
    _playbackTimer?.cancel();
    
    // Resume pitch detection
    _startPitchDetection();
    
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });

    // Resume metronome phase
    if (_metronomeEnabled) {
      _lastWholeBeat = -1;
    }

    // Ensure expected note is present when resuming (in case it was cleared)
    _scoreFuture.then((score) {
      if (!mounted) return;
      if (_expectedNote == null) {
        _updateExpectedNote(score);
      }
    });

    // Start stopwatch for precise timing on resume
    _playbackStopwatch?.stop();
    _playbackStopwatch = Stopwatch()..start();

    // Get the score from the future
    _scoreFuture.then((score) {
      if (!mounted) return;
      
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        setState(() {
          if (!_reachedEnd) {
            final double stopwatchSec = (_playbackStopwatch?.elapsedMicroseconds ?? 0) / 1e6;
            _currentTime = _elapsedBeforePauseSec + stopwatchSec;
            
            // Calculate note duration based on current BPM
            const double secondsPerMinute = 60.0;
            final double noteDuration = secondsPerMinute / _bpm;
            
            // Calculate total beats up to current time (used by metronome and note selection)
            final double metronomeBeatUnitSec = (60.0 / _bpm) * (4.0 / (_timeSigBeatType?.toDouble() ?? 4.0));
            final double currentBeats = _currentTime / metronomeBeatUnitSec;

            // End-of-sheet handling
            if (_currentTime >= _lastMeasurePosition) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
              _stopPitchDetection();
              _stopMetronome();
              // Show completion summary
              _showCompletionDialog();
              return; // short-circuit to avoid any triggers in this tick
            } else {
              // Metronome: trigger on every beat (catch up if timer skipped)
              if (_metronomeEnabled) {
                final int targetBeat = currentBeats.floor();
                const double clickDurationSec = 0.05; // 50ms
                while (_lastWholeBeat < targetBeat) {
                  _lastWholeBeat++;
                  final int beatsPerMeasure = (_timeSigBeats ?? 4).clamp(1, 12);
                  final bool isDownbeat = (_lastWholeBeat % beatsPerMeasure) == 0;
                  final double beatStartSec = _lastWholeBeat * metronomeBeatUnitSec;
                  if (beatStartSec + clickDurationSec <= _lastMeasurePosition) {
                    _triggerMetronome(downbeat: isDownbeat);
                  } else {
                    break; // don't schedule beyond end
                  }
                }
              }
            }
            
            // Find the current note based on beats
            double totalBeats = 0.0;
            int newNoteIndex = 0;
            bool foundNote = false;
            
            for (final measure in score.measures) {
              for (final note in measure.notes) {
                if (!note.isRest) {
                  if (currentBeats >= totalBeats && currentBeats < totalBeats + _getNoteDuration(note)) {
                    foundNote = true;
                    break;
                  }
                  newNoteIndex++;
                }
                totalBeats += _getNoteDuration(note);
              }
              if (foundNote) break;
            }
            
            // Update expected/current note on index change or if not set yet
            if (newNoteIndex != _currentNoteIndex || _expectedNote == null) {
              _currentNoteIndex = newNoteIndex;
              _updateExpectedNote(score);
            }
            
            // Stop if we've reached the end of the sheet
            if (_currentTime >= _lastMeasurePosition) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
              _stopPitchDetection();
              _stopMetronome();
            }
          }
        });
      });
    });
  }

  void _stopExercise() {
    // Cancel all timers
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _countdownTimer?.cancel();
    
    // Stop pitch detection
    _stopPitchDetection();
    _stopMetronome(immediate: true);
    
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentTime = 0.0;
      _showCountdown = false;
      _reachedEnd = false;
      _currentDetectedNote = null;
      _expectedNote = null;
      _isCorrect = false;
    });
    _elapsedBeforePauseSec = 0.0;
    _playbackStopwatch?.stop();
    _playbackStopwatch = null;
  }

  void _startMetronome() {
    _metronomeTimer?.cancel();
    // No separate timer during playback; we drive clicks from the playback timer via _currentTime
    _lastWholeBeat = -1;
  }

  void _stopMetronome({bool immediate = false}) {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    // Immediately stop any in-flight metronome sound to avoid extra click at the end
    try {
      if (_metronomePlayer.isOpen() && _metronomePlayer.isPlaying) {
        if (immediate) {
          // Hard stop (pause/stop actions)
          _metronomePlayer.stopPlayer();
        } else {
          // Let current click finish naturally at sheet end
          // Do nothing; player will end on its own
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _metronomeFlash = false);
  }

  Future<void> _playMetronomeClick({bool downbeat = false}) async {
    try {
      if (!_metronomePlayer.isOpen()) {
        try { await _metronomePlayer.openPlayer(); } catch (_) {}
        if (!_metronomePlayer.isOpen()) {
          // Fallback if we still cannot open
          try { SystemSound.play(SystemSoundType.click); } catch (_) {}
          return;
        }
      }
      // Avoid cutting the click if it's still within its duration; otherwise, force stop to allow a new click
      if (_metronomePlayer.isPlaying) {
        final int nowUs = DateTime.now().microsecondsSinceEpoch;
        final int elapsedMs = ((nowUs - _lastClickStartUs) / 1000).round();
        if (elapsedMs < _clickDurationMs - 5) {
          // Still in click window → skip retrigger to avoid cut
          return;
        }
        // Click should have finished by now but player still reports playing → stop to start the next
        try { await _metronomePlayer.stopPlayer(); } catch (_) {}
      }
      final Uint8List data = _generateClickPcm(
        frequencyHz: downbeat ? 1400 : 1000,
        durationMs: _clickDurationMs,
        sampleRate: 44100,
        amplitude: downbeat ? 0.6 : 0.4,
      );
      _lastClickStartUs = DateTime.now().microsecondsSinceEpoch;
      try {
        await _metronomePlayer.startPlayer(
          fromDataBuffer: data,
          codec: Codec.pcm16,
          numChannels: 1,
          sampleRate: 44100,
        );
      } catch (_) {
        // Fallback to system click if start failed
        try { SystemSound.play(SystemSoundType.click); } catch (_) {}
      }
    } catch (e) {
      // As a fallback, try a system click
      try { SystemSound.play(SystemSoundType.click); } catch (_) {}
    }
  }

  // Web beep removed; native click path only

  void _triggerMetronome({required bool downbeat}) {
    // Guard: if we've reached or passed the sheet end or not actively playing, do not click
    if (_currentTime >= _lastMeasurePosition || !_isPlaying) {
      return;
    }
    _playMetronomeClick(downbeat: downbeat);
    if (mounted) {
      setState(() => _metronomeFlash = true);
      Timer(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _metronomeFlash = false);
      });
    }
  }

  Uint8List _generateClickPcm({
    required double frequencyHz,
    required int durationMs,
    required int sampleRate,
    required double amplitude,
  }) {
    final int totalSamples = (sampleRate * durationMs / 1000).round();
    final Int16List samples = Int16List(totalSamples);
    final double twoPiF = 2 * math.pi * frequencyHz;

    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      // Simple short sine with exponential decay for a clicky feel
      final double envelope = math.exp(-20 * t); // fast decay
      final double s = math.sin(twoPiF * t) * amplitude * envelope;
      samples[i] = (s * 32767).clamp(-32768.0, 32767.0).toInt();
    }
    return samples.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Center(
            child: _buildBody(),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 64,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Level ${widget.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Score indicator centered at top
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _totalPlayableNotes > 0
                      ? 'Score: $_correctNotesCount / $_totalPlayableNotes  (${((_correctNotesCount / _totalPlayableNotes) * 100).clamp(0, 100).toStringAsFixed(0)}%)'
                      : 'Score: 0 / 0 (0%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_showCountdown && _countdown > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _countdown.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_metronomeEnabled && _isPlaying)
            Positioned(
              top: 16,
              right: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _metronomeFlash ? Colors.lightBlueAccent : Colors.white24,
                  shape: BoxShape.circle,
                  boxShadow: _metronomeFlash
                      ? [
                          BoxShadow(
                            color: Colors.lightBlueAccent.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Score>(
      future: _scoreFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        final score = snapshot.data!;
        
        // Calculate total duration based on actual note durations (more precise than measures * measureDuration)
        _lastMeasurePosition = _calculateScoreDurationSeconds(score);
        _totalDuration = _lastMeasurePosition;

        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // Music Sheet with glow (Flexible)
                  Flexible(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                        child: Align(
                          alignment: const Alignment(-0.8, 0.0),
                          child: MusicSheet(
                            score: score,
                            isPlaying: _isPlaying,
                            currentTime: _currentTime,
                            currentNoteIndex: _currentNoteIndex,
                            bpm: _bpm,
                            isCorrect: _isCorrect,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Notes (horizontal scrollable row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF181F2A),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.10),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: _buildScrollableNoteRow(score),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Control buttons row (in a card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF232B39),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.13),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous, size: 28, color: Colors.white),
                            tooltip: 'Previous Exercise',
                            onPressed: () {
                              // TODO: Implement previous exercise
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _metronomeEnabled ? Icons.music_note : Icons.music_note_outlined,
                              size: 26,
                              color: _metronomeEnabled ? Colors.lightBlueAccent : Colors.white,
                            ),
                            tooltip: 'Toggle Metronome',
                            onPressed: () {
                              setState(() {
                                _metronomeEnabled = !_metronomeEnabled;
                              });
                              if (_metronomeEnabled) {
                                _startMetronome();
                                _unlockWebAudioIfNeeded();
                              } else {
                                _stopMetronome();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay, size: 28, color: Colors.white),
                            tooltip: 'Replay',
                            onPressed: () {
                              _stopExercise();
                              _startCountdown();
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : 
                              _isPaused ? Icons.play_arrow : 
                              Icons.play_arrow,
                              size: 34,
                              color: Colors.white
                            ),
                            tooltip: _isPlaying ? 'Pause' : 
                                    _isPaused ? 'Resume' : 
                                    'Start',
                            onPressed: () {
                              if (_isPlaying) {
                                _pauseExercise();
                              } else if (_isPaused) {
                                _resumeExercise();
                              } else {
                                _startCountdown();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 28, color: Colors.white),
                            tooltip: 'Next Exercise',
                            onPressed: () {
                              // TODO: Implement next exercise
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 26, color: Colors.white),
                            tooltip: 'Settings',
                            onPressed: _showSettingsDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildScrollableNoteRow(Score score) {
    final notes = <String>[];
    for (final measure in score.measures) {
      for (final note in measure.notes) {
        if (!note.isRest) {
          notes.add("${note.step}${note.octave}");
        }
      }
    }
    return ListView.separated(
      controller: _noteScrollController,
      scrollDirection: Axis.horizontal,
      itemCount: notes.length,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      separatorBuilder: (context, idx) => const SizedBox(width: 12),
      itemBuilder: (context, idx) {
        final isCurrentNote = idx == _currentNoteIndex;
        final wasCorrect = _noteCorrectness[idx];
        
        // Determine the color based on whether the note was correct or not
        Color noteColor;
        if (isCurrentNote) {
          noteColor = _isCorrect ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8);
        } else if (wasCorrect != null) {
          noteColor = wasCorrect ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8);
        } else {
          noteColor = Colors.white;
        }

        return Container(
          decoration: BoxDecoration(
            color: noteColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.18),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            notes[idx],
            style: TextStyle(
              color: isCurrentNote || wasCorrect != null ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        );
      },
    );
  }

  // Calculate duration for a measure based on the score's time signature and current BPM
  double _calculateMeasureDuration(Score score) {
    const double secondsPerMinute = 60.0;
    // Get time signature from the score
    final int beats = score.beats;
    final int beatType = score.beatType;
    // Duration of a single beat as defined by time signature (e.g., eighth in 6/8)
    final double beatUnitSeconds = (secondsPerMinute / _bpm) * (4.0 / beatType);
    // Measure duration = beats per measure * beat unit duration
    return beats * beatUnitSeconds;
  }

  // Calculate precise score duration in seconds by summing note durations (including rests)
  double _calculateScoreDurationSeconds(Score score) {
    const double secondsPerMinute = 60.0;
    final int beatType = score.beatType;
    final double beatUnitSeconds = (secondsPerMinute / _bpm) * (4.0 / beatType);
    double totalBeats = 0.0;
    for (final measure in score.measures) {
      for (final note in measure.notes) {
        totalBeats += _getNoteDuration(note);
      }
    }
    return totalBeats * beatUnitSeconds;
  }

  void _showCompletionDialog() {
    if (!mounted) return;
    final int total = _totalPlayableNotes;
    final int correct = _correctNotesCount.clamp(0, total);
    final String percent = total > 0
        ? ((correct / total) * 100).clamp(0, 100).toStringAsFixed(0)
        : '0';

    // Save practice session to database
    _savePracticeSession(correct, total, percent);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF232B39),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Exercise Complete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Score: $correct / $total',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _stopExercise();
                _startCountdown();
              },
              child: const Text('Replay'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePracticeSession(int correctNotes, int totalNotes, String percentage) async {
    try {
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final duration = _currentTime;
      
      final session = {
        'level': widget.level,
        'score': correctNotes,
        'total_notes': totalNotes,
        'percentage': double.parse(percentage),
        'practice_date': date,
        'practice_time': time,
        'duration_seconds': duration,
        'created_at': now.toIso8601String(),
      };

      final dbHelper = DatabaseHelper();
      await dbHelper.insertPracticeSession(session);
    } catch (e) {
      print('Error saving practice session: $e');
    }
  }
} 