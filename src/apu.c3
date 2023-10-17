module apu;

import std::io;

import types;

import system;

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
}

fn void Apu.init(Apu* apu, System* system) {
	apu.system = system;
}

fn UInt8 Apu.read(Apu* apu, UInt16 addr) {
  switch(addr) {
		case 0xff24: return apu.regs.nr50;
		case 0xff25: return apu.regs.nr51;
    case 0xff26: return apu.regs.nr52;
    default: return 0xff;
  }
}

fn void Apu.write(Apu* apu, UInt16 addr, UInt8 value) {
  switch(addr) {
		case 0xff24: apu.regs.nr50 = value;
		case 0xff25: apu.regs.nr51 = value;
    case 0xff26: apu.regs.nr52 = value & 0x80;
  }
}

fn void Apu.tick(Apu* apu, UInt64 tick) {

}