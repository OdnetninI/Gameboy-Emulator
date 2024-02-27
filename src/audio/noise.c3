module apu::noise;
import apu::lengthduty;
import apu::envelope;

import types;

import std::math::random;

UInt16[8] divisor_code = {8, 16 ,32, 48, 64, 80, 96, 112};

struct Noise {
  LengthDuty lengthduty;
  Envelope envelope;
  UInt8 counter_consecutive;
  bool enable;
  UInt16 timer;
  UInt8 clock_sift;
  UInt8 width_mode;
  UInt8 divisor;
  UInt16 lfsr;
  Int16 output;
}

fn void Noise.init(&noise) {
  noise.lengthduty.init();
  noise.envelope.init();
  noise.counter_consecutive = 0;
  noise.enable = false;
  noise.timer = 0;
  noise.clock_sift = 0;
  noise.width_mode = 0;
  noise.divisor = 0;
  noise.lfsr = 0;
  noise.output = 0;
}

fn void Noise.tick_lfsr(&noise) {
  UInt8 xor_val = (UInt8)((noise.lfsr >> 1) ^ noise.lfsr) & 0x1;
  noise.lfsr = noise.lfsr >> 1;
  noise.lfsr = (noise.lfsr & ~0x4000) | ((UInt16)xor_val << 14);
  if (noise.width_mode != 0) {
    noise.lfsr = (noise.lfsr & ~0x0040) | (xor_val << 5);
  }

  if ((noise.lfsr & 0x1) == 0) {
    noise.output = 1;
  }
  else {
    noise.output = -1;
  }
}

fn void Noise.write_consecutive(&noise, UInt8 value) {
  noise.counter_consecutive = value & 0x40;
  if ((value & 0x80) != 0) {
    noise.trigger();
  }
}

fn void Noise.write_clock(&noise, UInt8 value) {
  noise.width_mode = value & 0x08;
  noise.clock_sift = (value & 0xf0) >> 4;
  noise.divisor = value & 0x07;
  noise.timer = divisor_code[noise.divisor] << noise.clock_sift; 
}

fn UInt8 Noise.read_clock(&noise) {
  return (noise.clock_sift << 4) | noise.width_mode | noise.divisor;
}

fn void Noise.tick(&noise) {
  if (noise.timer > 0) noise.timer -= 1;
  if (noise.timer == 0) {
    noise.tick_lfsr();
    noise.timer = divisor_code[noise.divisor] << noise.clock_sift; 
  }
}

fn Int16 Noise.get_sample(&noise) {
  if ((noise.counter_consecutive != 0 && noise.lengthduty.length > 0) || noise.enable) {
    return noise.output * noise.envelope.volume;
  }
  return 0;
}

fn void Noise.trigger(&noise) {
  noise.lengthduty.length = 63;
  noise.timer = divisor_code[noise.divisor] << noise.clock_sift;
  noise.envelope.timer = noise.envelope.period;
  noise.envelope.volume = noise.envelope.volume_init;
  noise.enable = true;
  noise.lfsr = 0x7fff;
}
