module apu::wave;

import types;

struct Wave {
  bool enable;
  LengthDuty lengthduty;
  UInt8 volume;
  UInt8 freq_lo;
  UInt8 freq_hi;
  UInt8[16] wave_data;
  UInt16 freq;
  UInt8 counter_enabled;
  UInt16 timer;
  UInt8 sample_pos;
}

fn void Wave.init(&wave) {
  wave.enable = false;
  wave.lengthduty.init();
  wave.volume = 0;
  wave.freq_lo = 0;
  wave.freq_hi = 0;
  wave.wave_data = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
  wave.freq = 0;
  wave.counter_enabled = 0;
  wave.sample_pos = 0;
  wave.timer = 0;
}

fn void Wave.freq_lo_write(&wave, UInt8 value) {
  wave.freq = (wave.freq & 0xf00) | value;
  wave.freq_lo = value;
}

fn void Wave.freq_hi_write(&wave, UInt8 value) {
  if (value & 0x80 != 0) {
    wave.trigger();
  }
  wave.counter_enabled = value & 0x40;
  wave.freq_hi = value;
  wave.freq = (wave.freq & 0x00ff) | ((value & 0x07) << 8);
}

fn void Wave.tick(&wave) {
    if (wave.timer > 0) wave.timer -= 1;
    if (wave.timer == 0) {
        wave.sample_pos = (wave.sample_pos + 1) % 32;
        wave.timer = (2048 - wave.freq) * 4;
    }
}

fn Int16 Wave.get_sample(&wave) {
  if ((wave.counter_enabled != 0 && wave.lengthduty.length > 0) || wave.enable) {
    UInt8 sample = wave.wave_data[wave.sample_pos / 2];
    if (wave.sample_pos % 2 == 0) {
      return sample >> 4;
    }
    else {
      return sample & 0xF;
    }
  }
  return 0;
}

fn void Wave.trigger(&wave) {
  wave.lengthduty.length = 255;
  wave.timer = (2048 - wave.freq) * 4;
  wave.sample_pos = 0;
  wave.enable = true;
}
