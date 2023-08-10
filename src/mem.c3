module mem;

import std::io;

import types;

import system;

struct Mem {
  System* system;
  UInt8[0x100] bios;
  UInt8[0x10000] memory;
  bool bios_enabled;
}

fn void Mem.init(Mem* mem, System* system) {
  mem.system = system;
  mem.bios_enabled = true;
  mem.memory[0xFF0F] = 0x00;
}

fn UInt8 Mem.read(Mem* mem, Addr addr) {
  //io::printfn("Read from %04x", addr);
  switch (addr) {
    case 0x0000..0x00FF:
      if (mem.bios_enabled) return mem.bios[addr];
      return mem.memory[addr];
    case 0xFF40..0xFF4B:
      return mem.system.ppu.read(addr);
  }
  return mem.memory[addr];
}

fn UInt16 Mem.read16(Mem* mem, Addr addr) {
  Mem16 data = { .low = mem.read(addr), .high = mem.read(addr + 1) };
  return data.value;
}

fn void Mem.write(Mem* mem, Addr addr, UInt8 value) {
  //io::printfn("Write to %04x", addr);
  switch (addr) {
    case 0x0000..0x00FF: if (mem.bios_enabled) mem.bios[addr] = value; return;
    case 0xFF40..0xFF4B:
      mem.system.ppu.write(addr, value);
      return;
    case 0xFF50: if (value != 0x00) mem.bios_enabled = false;
  }
  mem.memory[addr] = value;
}

fn void Mem.write16(Mem* mem, Addr addr, UInt16 value) {
  Mem16 data = { .value = value };
  mem.write(addr, data.low);
  mem.write(addr + 1, data.high);
}