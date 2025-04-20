class NoteUtils {
  static const noteFrequencies = {
    'C4': 261.63,
    'D4': 293.66,
    'E4': 329.63,
    'F4': 349.23,
    'G4': 392.00,
    'A4': 440.00,
    'B4': 493.88,
    'C5': 523.25,
  };

  static String frequencyToNote(double frequency) {
    double minDiff = double.infinity;
    String closestNote = '';

    noteFrequencies.forEach((note, noteFreq) {
      double diff = (frequency - noteFreq).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNote = note;
      }
    });

    return closestNote;
  }
}
