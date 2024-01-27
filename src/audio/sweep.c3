module apu::sweep;

import types;

struct Sweep {
  UInt8 period;
  UInt8 negate;
  UInt8 shift;
  UInt16 freq;
  UInt8 timer;
  bool enabled;
}

fn void Sweep.init(&sweep) {
  sweep.period = 0;
  sweep.negate = 0;
  sweep.shift = 0;
  sweep.freq = 0;
  sweep.timer = 0;
  sweep.enabled = false;
}

fn UInt8 Sweep.read(&sweep) {
  return (sweep.period << 4) | sweep.negate | sweep.shift;
}

fn void Sweep.write(&sweep, UInt8 value) {
  sweep.period = (value & 0x70) >> 4;
  sweep.negate = value & 0x08;
  sweep.shift = value & 0x07;
}

fn UInt16 Sweep.calculate(&sweep) {
  UInt16 freq = (sweep.negate != 0) ? 
                (sweep.freq - (sweep.freq >> sweep.shift)) :
                (sweep.freq + (sweep.freq >> sweep.shift));

  if (freq > 2047) sweep.enabled = false;
  return freq;
}
