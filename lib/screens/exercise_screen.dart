import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/music_service.dart';
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
  double _currentTime = 0.0;
  double _totalDuration = 0.0;
  bool _reachedEnd = false;
  double _lastMeasurePosition = 1;
  int _currentNoteIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playbackTimer?.cancel();
    _pulseController.dispose();
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

  void _startExercise() {
    // Cancel any existing timers
    _playbackTimer?.cancel();
    
    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _reachedEnd = false;
      _currentTime = 0.0;  // Reset to start at the first note
      _currentNoteIndex = 0; // Reset to first note
    });

    // Get the score from the future
    _scoreFuture.then((score) {
      // Calculate beat duration based on tempo (default 120 BPM)
      const double tempo = 120.0; // beats per minute
      const double secondsPerMinute = 60.0;
      final double beatDuration = secondsPerMinute / tempo; // duration of one beat in seconds
      
      // Start playback timer
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (mounted) {
          setState(() {
            if (!_reachedEnd) {
              _currentTime += 0.05; // Increment by 50ms
              
              // Update current note index based on beat duration
              _currentNoteIndex = (_currentTime / beatDuration).floor();
              
              // Stop if we've reached the end (last measure position + extra time)
              if (_currentTime >= _lastMeasurePosition + 10.0) {
                _reachedEnd = true;
                _isPlaying = false;
                _playbackTimer?.cancel();
              }
            }
          });
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _pauseExercise() {
    // Cancel the playback timer
    _playbackTimer?.cancel();
    _playbackTimer = null;
    
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  void _resumeExercise() {
    // Ensure no existing timer is running
    _playbackTimer?.cancel();
    
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          if (!_reachedEnd) {
            _currentTime += 0.05;
            
            // Stop if we've reached the end (last measure position + extra time)
            if (_currentTime >= _lastMeasurePosition + 10.0) {
              _reachedEnd = true;
              _isPlaying = false;
              _playbackTimer?.cancel();
            }
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _stopExercise() {
    // Cancel all timers
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _countdownTimer?.cancel();
    
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentTime = 0.0;  // Reset to start at the first note
      _showCountdown = false;
      _reachedEnd = false;
    });
  }

  // Calculate duration for a measure based on the score's time signature
  double _calculateMeasureDuration(Score score) {
    // Default tempo is 120 BPM (beats per minute)
    const double defaultTempo = 120.0;
    const double secondsPerMinute = 60.0;
    
    // Get time signature from the score
    final beats = score.beats;
    final beatType = score.beatType;
    
    // Calculate duration in seconds
    // For 4/4 time, one measure = 4 beats at 120 BPM = 2 seconds
    return (beats * secondsPerMinute) / defaultTempo;
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
                            onPressed: () {
                              // TODO: Implement settings/options
                            },
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
      scrollDirection: Axis.horizontal,
      itemCount: notes.length,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      separatorBuilder: (context, idx) => const SizedBox(width: 12),
      itemBuilder: (context, idx) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        );
      },
    );
  }
} 