module mem;

import types;

import system;

struct Mem {
  System* system;
  UInt8[0x10000] memory;
}

fn UInt8 Mem.read(Mem* mem, Addr addr) {
  /*switch (addr) {
    case 0xFF40..0xFF45:
    case 0xFF47..0xFF4B:
      return mem.system.ppu.read(addr);
  }*/
  return mem.memory[addr];
}

fn UInt16 Mem.read16(Mem* mem, Addr addr) {
  Mem16 data = { .low = mem.read(addr), .high = mem.read(addr + 1) };
  return data.value;
}

fn void Mem.write(Mem* mem, Addr addr, UInt8 value) {
  /*switch (addr) {
    case 0xFF40..0xFF45:
    case 0xFF47..0xFF4B:
      mem.system.ppu.write(addr, value);
      return;
  }*/
  mem.memory[addr] = value;
}

fn void Mem.write16(Mem* mem, Addr addr, UInt16 value) {
  Mem16 data = { .value = value };
  mem.write(addr, data.low);
  mem.write(addr + 1, data.high);
}