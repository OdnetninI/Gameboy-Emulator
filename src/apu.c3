// Audio subsystem is ported from sponGB on github from kugo12
// I tried to make my own audio subsystem... but I was not able after so many tries T_T

module apu;

import std::io;

import types;

import system;

import raylib;

struct ApuRegs {
	bitstruct : UInt8 @overlap {
    UInt8 nr50 :  0..7;
    bool vin_l : 7;
    UInt8 left_v : 4..6;
    bool vin_r : 3;
    UInt8 right_v : 0..2;
  }
	bitstruct : UInt8 @overlap {
    UInt8 nr51 :  0..7;
    bool ch4_l : 7;
    bool ch3_l : 6;
    bool ch2_l : 5;
    bool ch1_l : 4;
    bool ch4_r : 3;
		bool ch3_r : 2;
		bool ch2_r : 1;
		bool ch1_r : 0;
  }
  bitstruct : UInt8 @overlap {
    UInt8 nr52 :  0..7;
    bool audio_on : 7;
    bool ch4_on : 3; // Read-only
    bool ch3_on : 2; // Read-only
    bool ch2_on : 1; // Read-only
    bool ch1_on : 0; // Read-only
  }
}

struct Apu {
  System* system;
  ApuRegs regs;
  AudioStream audio_stream;
  Int16[8192 * 2] audio_samples;
  UInt64 sample_clock;
  UInt64 frame_clock;
  UInt64 clock;

  // Channels
  apu::square::Square sc1;
  apu::square::Square sc2;
  apu::wave::Wave sc3;
  apu::noise::Noise sc4;
}

fn void Apu.init(&apu, System* system) {
	apu.system = system;UInt8 nr33;
  apu.sample_clock = 0;
  apu.frame_clock = 0;
  apu.clock = 0;

  apu.sc1.init(true);
  apu.sc2.init(false);
  apu.sc3.init();
  apu.sc4.init();

  for (int i = 0; i < 8192 * 2; ++i) {
    apu.audio_samples[i] = 0;
  }

  raylib::init_audio_device();
  raylib::set_audio_stream_buffer_size_default(8192);
  apu.audio_stream = raylib::load_audio_stream(48000, 16, 2);
  raylib::play_audio_stream(apu.audio_stream);
}

fn UInt8 Apu.read(&apu, UInt16 addr) {
  switch(addr) {
    case 0xff10: return apu.sc1.sweep.read();
    case 0xff11: return apu.sc1.lengthduty.read();
    case 0xff12: return apu.sc1.envelope.read();
    case 0xff13: return (UInt8)apu.sc1.freq;
    case 0xff14: return apu.sc1.freq_hi;
    
    case 0xff16: return apu.sc2.lengthduty.read();
    case 0xff17: return apu.sc2.envelope.read();
    case 0xff18: return (UInt8)apu.sc2.freq;
    case 0xff19: return apu.sc2.freq_hi;
    
    case 0xff1a: return (((UInt8)apu.sc3.enable) << 7) | 0x7f;
    case 0xff1b: return apu.sc3.lengthduty.length;
    case 0xff1c: return (apu.sc3.volume << 5) | 0x9f;
    case 0xff1d: return apu.sc3.freq_lo;
    case 0xff1e: return apu.sc3.freq_hi;
    case 0xff30..0xff3f: return apu.sc3.wave_data[addr - 0xff30];

    case 0xff20: return apu.sc4.lengthduty.read() | 0xc0;
    case 0xff21: return apu.sc4.envelope.read();
    case 0xff22: return apu.sc4.read_clock();
    case 0xff23: return apu.sc4.counter_consecutive | 0x3f; 

		case 0xff24: return apu.regs.nr50;
		case 0xff25: return apu.regs.nr51;
    case 0xff26: return apu.regs.nr52;
    default: return 0xff;
  }
}

fn void Apu.write(&apu, UInt16 addr, UInt8 value) {
  switch(addr) {
    case 0xff10: apu.sc1.sweep.write(value);
    case 0xff11: apu.sc1.lengthduty.write(value);
    case 0xff12: apu.sc1.envelope.write(value);
    case 0xff13: apu.sc1.freq_lo_write(value);
    case 0xff14: apu.sc1.freq_hi_write(value);

    case 0xff16: apu.sc2.lengthduty.write(value);
    case 0xff17: apu.sc2.envelope.write(value);
    case 0xff18: apu.sc2.freq_lo_write(value);
    case 0xff19: apu.sc2.freq_hi_write(value);

    case 0xff1a: apu.sc3.enable = (value & 0x80) != 0;
    case 0xff1b: apu.sc3.lengthduty.length = value;
    case 0xff1c: apu.sc3.volume = (value >> 5) & 0x03;
    case 0xff1d: apu.sc3.freq_lo_write(value);
    case 0xff1e: apu.sc3.freq_hi_write(value);
    case 0xff30..0xff3f: apu.sc3.wave_data[addr - 0xff30] = value;

    case 0xff20: apu.sc4.lengthduty.write(value);
    case 0xff21: apu.sc4.envelope.write(value);
    case 0xff22: apu.sc4.write_clock(value);
    case 0xff23: apu.sc4.write_consecutive(value);

		case 0xff24: apu.regs.nr50 = value;
		case 0xff25: apu.regs.nr51 = value;
    case 0xff26: apu.regs.nr52 = value & 0x80;
  }
}

fn void Apu.tick(&apu, UInt64 tick) {
  apu.sc1.tick();
  apu.sc2.tick();
  apu.sc3.tick();
  apu.sc4.tick();

  if (apu.clock == 8192) {
    if (apu.frame_clock % 2 == 0) {
      apu.sc1.lengthduty.tick(& apu.sc1.enabled);
      apu.sc2.lengthduty.tick(& apu.sc2.enabled);
      apu.sc3.lengthduty.tick(& apu.sc3.enable);
      apu.sc4.lengthduty.tick(& apu.sc4.enable);
    }
    if (apu.frame_clock == 7) {
      apu.sc1.envelope.tick();
      apu.sc2.envelope.tick();
      apu.sc4.envelope.tick();
    }
    if (apu.frame_clock % 4 == 2) {
      apu.sc1.sweep_tick();
    }
    apu.frame_clock = (apu.frame_clock + 1) % 8;
    apu.clock = 0;
  }

  if (apu.sample_clock % 87 == 0) {
    UInt64 pos = (apu.sample_clock / 87) * 2;

    Int16 l = 0;
    Int16 r = 0;

    Int16 s1 = apu.sc1.get_sample();
    Int16 s2 = apu.sc2.get_sample();
    Int16 s3 = apu.sc3.get_sample();
    Int16 s4 = apu.sc4.get_sample();

    if (apu.regs.audio_on) {
      if (apu.regs.ch1_l) l += s1; 
      if (apu.regs.ch1_r) r += s1;
      if (apu.regs.ch2_l) l += s2; 
      if (apu.regs.ch2_r) r += s2;
      if (apu.regs.ch3_l) l += s3; 
      if (apu.regs.ch3_r) r += s3;
      if (apu.regs.ch4_l) l += s4; 
      if (apu.regs.ch4_r) r += s4;

      l = l * apu.regs.left_v;
      r = r * apu.regs.right_v;
    }

    apu.audio_samples[pos] = l * 4;
    apu.audio_samples[pos + 1] = r * 4;

    if (pos == (8192 - 2)) {
      while(!raylib::is_audio_stream_processed(apu.audio_stream));
      raylib::update_audio_stream(apu.audio_stream, apu.audio_samples[:8192], 8192);
      apu.sample_clock = 0;
    }
    else {
      apu.sample_clock++;
    }
  }
  else {
    apu.sample_clock++;
  }
  apu.clock++;
}
