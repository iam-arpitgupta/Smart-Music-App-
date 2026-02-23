import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart'; // To access global audioHandler

enum SleepTimerMode {
  off,
  endOfTrack,
  minutes15,
  minutes30,
  minutes45,
  hour1,
}

class SleepTimerState {
  final SleepTimerMode mode;
  final Duration? remainingTime;

  SleepTimerState({
    this.mode = SleepTimerMode.off,
    this.remainingTime,
  });

  SleepTimerState copyWith({
    SleepTimerMode? mode,
    Duration? remainingTime,
    bool clearRemainingTime = false,
  }) {
    return SleepTimerState(
      mode: mode ?? this.mode,
      remainingTime: clearRemainingTime ? null : (remainingTime ?? this.remainingTime),
    );
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  Timer? _countdownTimer;
  StreamSubscription? _playbackEventSubscription;

  SleepTimerNotifier() : super(SleepTimerState()) {
    // Listen to playback state to detect "End of Track" 
    // audio_service typically transitions to processingState == idle/completed when finished
    _playbackEventSubscription = audioHandler.playbackState.listen((state) {
      if (this.state.mode == SleepTimerMode.endOfTrack) {
        // If it's paused randomly or completed natively
        if (!state.playing && state.processingState != null) {
            cancelTimer();
            audioHandler.stop();
        }
      }
    });
  }

  void setTimer(SleepTimerMode newMode) {
    _countdownTimer?.cancel();

    if (newMode == SleepTimerMode.off) {
      state = SleepTimerState();
      return;
    }

    if (newMode == SleepTimerMode.endOfTrack) {
      state = SleepTimerState(mode: newMode);
      return;
    }

    // Handle fixed duration timers
    Duration duration;
    switch (newMode) {
      case SleepTimerMode.minutes15:
        duration = const Duration(minutes: 15);
        break;
      case SleepTimerMode.minutes30:
        duration = const Duration(minutes: 30);
        break;
      case SleepTimerMode.minutes45:
        duration = const Duration(minutes: 45);
        break;
      case SleepTimerMode.hour1:
        duration = const Duration(hours: 1);
        break;
      default:
        duration = Duration.zero;
    }

    state = SleepTimerState(mode: newMode, remainingTime: duration);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingTime == null) {
        timer.cancel();
        return;
      }

      final newRemaining = state.remainingTime! - const Duration(seconds: 1);
      
      if (newRemaining.inSeconds <= 0) {
        // Time is up! Stop audio.
        timer.cancel();
        state = SleepTimerState(); // reset to off
        audioHandler.stop(); // or pause() depending on exact need
      } else {
        state = state.copyWith(remainingTime: newRemaining);
      }
    });
  }

  void cancelTimer() {
    _countdownTimer?.cancel();
    state = SleepTimerState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playbackEventSubscription?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier();
});
