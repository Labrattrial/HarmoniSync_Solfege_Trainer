import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/enhanced_yin.dart';

class PitchDebugScreen extends StatefulWidget {
	const PitchDebugScreen({super.key});

	@override
	State<PitchDebugScreen> createState() => _PitchDebugScreenState();
}

class _PitchDebugScreenState extends State<PitchDebugScreen> {
	final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
	final StreamController<Uint8List> _pcmController = StreamController<Uint8List>.broadcast();

	EnhancedYin? _enhanced;
	double? _lastPitch;
	bool _recording = false;
	bool _hasPermission = false;

	// Configurable parameters
	int _sampleRate = 44100;
	int _frameSize = 2048; // samples
	double _wienerStrength = 0.5;
	double _vadSensitivity = 0.6;
	int _medianWindow = 5;
	int _upsample = 2;
	bool _parabolic = true;

	// Buffer incoming PCM bytes until we have a full frame
	final List<int> _byteBuffer = <int>[];

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final mic = await Permission.microphone.request();
		_hasPermission = mic.isGranted;
		if (!_hasPermission) {
			setState(() {});
			return;
		}

		await _recorder.openRecorder();
		_enhanced = EnhancedYin(
			sampleRate: _sampleRate,
			wienerStrength: _wienerStrength,
			vadSensitivity: _vadSensitivity,
			medianWindow: _medianWindow,
			upsampleFactor: _upsample,
			enableParabolicRefinement: _parabolic,
		);

		_pcmController.stream.listen((Uint8List chunk) {
			_byteBuffer.addAll(chunk);
			final int frameBytes = _frameSize * 2; // PCM16 mono
			while (_byteBuffer.length >= frameBytes) {
				final Uint8List frame = Uint8List.fromList(_byteBuffer.sublist(0, frameBytes));
				_byteBuffer.removeRange(0, frameBytes);
				final double? hz = _enhanced?.processFrame(frame, _sampleRate);
				setState(() {
					_lastPitch = hz;
				});
			}
		});

		setState(() {});
	}

	Future<void> _start() async {
		if (!_hasPermission || _recording) return;
		await _recorder.startRecorder(
			toStream: _pcmController.sink,
			codec: Codec.pcm16,
			sampleRate: _sampleRate,
			numChannels: 1,
			bitRate: 256000,
		);
		setState(() {
			_recording = true;
		});
	}

	Future<void> _stop() async {
		if (!_recording) return;
		await _recorder.stopRecorder();
		setState(() {
			_recording = false;
		});
	}

	void _rebuildEnhanced() {
		_enhanced = EnhancedYin(
			sampleRate: _sampleRate,
			wienerStrength: _wienerStrength,
			vadSensitivity: _vadSensitivity,
			medianWindow: _medianWindow,
			upsampleFactor: _upsample,
			enableParabolicRefinement: _parabolic,
		);
	}

	@override
	void dispose() {
		_recorder.closeRecorder();
		_pcmController.close();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Pitch Debug')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						if (!_hasPermission)
							Text('Microphone permission required', style: Theme.of(context).textTheme.titleMedium),
						Row(
							children: [
								ElevatedButton(
									onPressed: _recording ? _stop : _start,
									child: Text(_recording ? 'Stop' : 'Start'),
								),
								const SizedBox(width: 12),
								Text(_recording ? 'Recording...' : 'Idle'),
							],
						),
						const SizedBox(height: 24),
						Text('Pitch: ${_lastPitch == null ? '—' : _lastPitch!.toStringAsFixed(1) + ' Hz'}',
							style: Theme.of(context).textTheme.headlineSmall),
						const SizedBox(height: 24),
						Wrap(
							spacing: 16,
							runSpacing: 8,
							children: [
								_filterSlider(
									title: 'Wiener',
									value: _wienerStrength,
									min: 0.0,
									max: 1.0,
									onChanged: (v) => setState(() {
										_wienerStrength = v;
										_rebuildEnhanced();
									}),
								),
								_filterSlider(
									title: 'VAD sens',
									value: _vadSensitivity,
									min: 0.3,
									max: 0.9,
									onChanged: (v) => setState(() {
										_vadSensitivity = v;
										_rebuildEnhanced();
									}),
								),
								_rowPicker(
									title: 'Median',
									value: _medianWindow,
									candidates: const [3,5,7,9],
									onChanged: (v) => setState(() {
										_medianWindow = v;
										_rebuildEnhanced();
									}),
								),
								_rowPicker(
									title: 'Upsample',
									value: _upsample,
									candidates: const [1,2,3],
									onChanged: (v) => setState(() {
										_upsample = v;
										_rebuildEnhanced();
									}),
								),
								SwitchListTile(
									title: const Text('Parabolic refine'),
									value: _parabolic,
									onChanged: (v) => setState(() {
										_parabolic = v;
										_rebuildEnhanced();
									}),
								),
						],
						),
					],
				),
			),
		);
	}

	Widget _filterSlider({required String title, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
		return SizedBox(
			width: 300,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text('$title: ${value.toStringAsFixed(2)}'),
					Slider(value: value, min: min, max: max, onChanged: onChanged),
				],
			),
		);
	}

	Widget _rowPicker({required String title, required int value, required List<int> candidates, required ValueChanged<int> onChanged}) {
		return Row(
			mainAxisSize: MainAxisSize.min,
			children: [
				Text('$title: '),
				const SizedBox(width: 8),
				DropdownButton<int>(
					value: value,
					items: [for (final v in candidates) DropdownMenuItem(value: v, child: Text('$v'))],
					onChanged: (v) {
						if (v != null) onChanged(v);
					},
				),
			],
		);
	}
} 