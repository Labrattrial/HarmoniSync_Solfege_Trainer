import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/music_service.dart';
import '../services/yin_algorithm.dart';
import '../utils/note_utils.dart';
import '../widgets/music_sheet.dart';

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
  Timer? _pitchDetectionTimer;
  double _currentTime = 0.0;
  double _totalDuration = 0.0;
  bool _reachedEnd = false;
  double _lastMeasurePosition = 1;
  int _currentNoteIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _glowColorAnimation;
  late FlutterSoundRecorder _recorder;
  String? _currentDetectedNote;
  String? _expectedNote;
  bool _isCorrect = false;
  StreamSubscription? _audioStreamSubscription;
  StreamController<Uint8List>? _audioStreamController;
  double _bpm = 120.0; // Default BPM
  final ScrollController _noteScrollController = ScrollController();
  final Map<int, bool> _noteCorrectness = {};

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
    
    // Ensure initial BPM is within valid range
    _bpm = _bpm.clamp(40.0, 244.0);
  }

  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
    await _recorder.openRecorder();
  }

  void _startPitchDetection() async {
    try {
      _audioStreamController = StreamController<Uint8List>();
      
      await _recorder.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 44100,
      );

      _audioStreamSubscription = _audioStreamController!.stream.listen((buffer) {
        if (!_isPlaying) return;

        try {
          final frequency = YinAlgorithm.detectPitch(buffer, 44100);
          if (frequency != null) {
            final note = NoteUtils.frequencyToNote(frequency);
            setState(() {
              _currentDetectedNote = note;
              if (_expectedNote != null) {
                _isCorrect = note == _expectedNote;
                // Store the correctness state for the current note
                _noteCorrectness[_currentNoteIndex] = _isCorrect;
                // Update glow color based on correctness
                _glowColorAnimation = ColorTween(
                  begin: Colors.transparent,
                  end: _isCorrect 
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
                ).animate(_pulseController);
              }
            });
          }
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
    _audioStreamSubscription?.cancel();
    _audioStreamController?.close();
    _pulseController.dispose();
    _recorder.closeRecorder();
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
    });

    // Start pitch detection
    _startPitchDetection();

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
            _currentTime += 0.05; // Increment by 50ms
            
            // Calculate note duration based on current BPM
            const double secondsPerMinute = 60.0;
            final double noteDuration = secondsPerMinute / _bpm;
            
            // Calculate total beats up to current time
            final double currentBeats = _currentTime / noteDuration;
            
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
            
            // Update current note index if it changed
            if (newNoteIndex != _currentNoteIndex) {
              _currentNoteIndex = newNoteIndex;
              _updateExpectedNote(score);
            }
            
            // Stop if we've reached the end (last measure position + extra time)
            if (_currentTime >= _lastMeasurePosition + 10.0) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
              _stopPitchDetection();
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
            _currentTime += 0.05;
            
            // Calculate note duration based on current BPM
            const double secondsPerMinute = 60.0;
            final double noteDuration = secondsPerMinute / _bpm;
            
            // Calculate total beats up to current time
            final double currentBeats = _currentTime / noteDuration;
            
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
            
            // Update current note index if it changed
            if (newNoteIndex != _currentNoteIndex) {
              _currentNoteIndex = newNoteIndex;
              _updateExpectedNote(score);
            }
            
            // Stop if we've reached the end (last measure position + extra time)
            if (_currentTime >= _lastMeasurePosition + 10.0) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
              _stopPitchDetection();
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
        
        // Calculate total duration based on the score's time signature
        final measureDuration = _calculateMeasureDuration(score);
        _lastMeasurePosition = score.measures.length * measureDuration;
        _totalDuration = _lastMeasurePosition + 10.0;  // Add 10 seconds after the last measure

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
    final beats = score.beats;
    final beatType = score.beatType;
    
    // Calculate duration in seconds based on current BPM
    return (beats * secondsPerMinute) / _bpm;
  }
} 