module io;

import types;
import system;

import std::io;

struct Io {
  System* system;
  UInt8[0xe0] memory;
}

fn void Io.init(Io* io, System* system) {
  io.system = system;
  
  io.memory[0xff0f - 0xfea0] = 0x00;
}

fn UInt8 Io.read(Io* io, UInt16 addr) {
  switch(addr) {
    case 0xff04: io::printfn("DIV -> %02x", (UInt8)((io.system.sysclk >> 6) & 0xff)); return (UInt8)((io.system.sysclk >> 6) & 0xff);
    case 0xff40..0xff4b: return io.system.ppu.read_io(addr);
    default: return io.memory[addr - 0xfea0];
  }
}

fn void Io.write(Io* io, UInt16 addr, UInt8 value) {
  switch(addr) {
    case 0xff04: io.system.sysclk = 0;
    case 0xff40..0xff4b: io.system.ppu.write_io(addr, value);
    case 0xff50: if (value != 0x00) io.system.bios_enabled = false; io.memory[addr - 0xfea0] = value;
    default: io.memory[addr - 0xfea0] = value;
  }
}