module io;

import types;
import system;

import std::io;

struct Io {
  System* system;
  UInt8[0xe0] memory;

  UInt8 tima;
  UInt8 tma;
  bitstruct : UInt8 @overlap {
    UInt8 tac : 0..7;
    bool tac_enabled : 2;
    UInt8 tac_speed : 0..1;
  }
}

fn void Io.init(Io* io, System* system) {
  io.system = system;
  
  io.memory[0xff0f - 0xfea0] = 0x00;
}

fn void Io.tick(Io* io, UInt64 tick_counter) {
  if (io.tac_enabled) {
    UInt64 speed = 1;
    switch(io.tac_speed) {
      case 0b00: speed = 1024;
      case 0b01: speed = 16;
      case 0b10: speed = 64;
      case 0b11: speed = 256;
    }
    if (tick_counter % speed == 0) {
      if (io.tima == 0xff) {
        io.tima = io.tma;
        UInt8 _if = io.system.read(0xFF0F);
        _if = _if | (1 << 2);
        io.system.write(0xFF0F, _if);
      }
      else {
        io.tima++;
      }
    }
  }
}

fn UInt8 Io.read(Io* io, UInt16 addr) {
  switch(addr) {
    case 0xff01..0xff02: return io.system.serial.read(addr);
    case 0xff04: return (UInt8)((io.system.sysclk >> 6) & 0xff);
    case 0xff05: return io.tima;
    case 0xff06: return io.tma;
    case 0xff07: return io.tac;
    case 0xff40..0xff4b: return io.system.ppu.read_io(addr);
    default: return io.memory[addr - 0xfea0];
  }
}

fn void Io.write(Io* io, UInt16 addr, UInt8 value) {
  switch(addr) {
    case 0xff01..0xff02: return io.system.serial.write(addr, value);
    case 0xff04: io.system.sysclk = 0;
    case 0xff05: io.tima = value;
    case 0xff06: io.tma = value;
    case 0xff07: io.tac = value;
    case 0xff40..0xff4b: io.system.ppu.write_io(addr, value);
    case 0xff50: if (value != 0x00) io.system.bios_enabled = false; io.memory[addr - 0xfea0] = value;
    default: io.memory[addr - 0xfea0] = value;
  }
}