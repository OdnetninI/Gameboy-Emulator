module apu::square;

import types;

struct Square {
  LengthDuty lengthduty;
  Envelope envelope;
  UInt8 freq_lo;
  UInt8 freq_hi;
  UInt16 timer;
  UInt8 duty_pos;
  UInt16 freq;
  UInt8 counter_enabled;
  Sweep sweep;
  bool sweep_enable;
  bool enabled;
}

fn void Square.init(&square, bool sweep_enable) {
  square.lengthduty.init();
  square.envelope.init();
  square.sweep.init();
  square.freq_lo = 0;
  square.freq_hi = 0;
  square.timer = 0;
  square.duty_pos = 0;
  square.freq = 0;
  square.counter_enabled = 0;
  square.sweep_enable = sweep_enable;
  square.enabled = false;
}

fn void Square.freq_lo_write(&square, UInt8 value) {
  square.freq = (square.freq & 0xf00) | value;
  square.freq_lo = value;
}

fn void Square.freq_hi_write(&square, UInt8 value) {
  if (value & 0x80 != 0) {
    square.trigger();
  }
  square.counter_enabled = value & 0x40;
  square.freq_hi = value;
  square.freq = (square.freq & 0x00ff) | ((value & 0x07) << 8);
}

fn void Square.tick(&square) {
  if (square.timer > 0) {
    square.timer -= 1;
  }
  if (square.timer == 0) {
    square.duty_pos = (square.duty_pos + 1) % 8;
    square.timer = (2048 - square.freq) * 4;
  }
}

fn Int16 Square.get_sample(&square) {
  if ((square.counter_enabled != 0 && square.lengthduty.length > 0) || square.enabled) {
    return square.lengthduty.dutyTable[square.duty_pos] * square.envelope.volume;   
  }
  return 0;
}

fn void Square.trigger(&square) {
  square.lengthduty.length = 63;
  square.timer = (2048 - square.freq) * 4;
  square.envelope.timer = square.envelope.period;
  square.envelope.volume = square.envelope.volume_init;
  square.duty_pos = 0;
  square.enabled = true;

  if (square.sweep_enable) {
    square.sweep.freq = (UInt8)square.freq;
    square.sweep.timer = square.sweep.period;
    square.sweep.enabled = square.sweep.period != 0 || square.sweep.shift != 0;
    if (square.sweep.shift != 0) {
      square.sweep.calculate();
    }
  }
}

fn void Square.sweep_tick(&square) {
  if (square.sweep.timer > 0) {
    square.sweep.timer -= 1;
  }
  if (square.sweep.period > 0) {
    if (square.sweep.timer == 0 && square.sweep_enable) {
      square.sweep.timer = square.sweep.period;

      UInt16 n = square.sweep.calculate();
      if (square.sweep.shift > 0 && n < 2048) {
        square.sweep.freq = n;
        square.freq = n;

        square.sweep.calculate();
      }
    }
  }
}
