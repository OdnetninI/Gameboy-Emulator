module system;

import std::io;

import types;

import cpu;
import io;
import ppu;
import lcd;
import input;
import cart;
import serial;

struct System {
  Cpu cpu;
  Ppu ppu;
  Lcd lcd;
  Cart cart;
  Io io;
  Serial serial;

  UInt8[0x100] bios;
  UInt8[0x2000] ram;
  UInt8[0x7f] hram;
  UInt8 interrupts;
  bool bios_enabled;

  UInt64 tick_counter;
  UInt16 sysclk;
}

fn void System.init(System* system) {
  system.cpu.init(system);
  system.ppu.init(system);
  system.lcd.init();
  system.cart.init(system);
  system.io.init(system);
  system.serial.init(system);

  system.bios_enabled = true;
}

fn void System.tick(System* system) {
  input::updateKeys(system);
  system.cpu.tick(system.tick_counter);
  system.ppu.tick(system.tick_counter);
  system.io.tick(system.tick_counter);
  system.serial.tick(system.tick_counter);

  system.sysclk++;
  system.tick_counter++;
}

fn UInt8 System.read(System* system, UInt16 addr) {
  switch(addr) {
    case 0x0000..0x00ff: 
      if (system.bios_enabled) return system.bios[addr - 0x0000];
      return system.cart.read(addr - 0x0000); 
    case 0x0100..0x7fff: return system.cart.read(addr - 0x0000); 
    case 0x8000..0x9fff: return system.ppu.read(addr - 0x8000);
    case 0xa000..0xbfff: return system.cart.ram_read(addr - 0xa000);
    case 0xc000..0xdfff: return system.ram[addr - 0xc000];
    case 0xe000..0xfdff: return system.ram[addr - 0xe000];
    case 0xfe00..0xfe9f: return system.ppu.oam_read(addr - 0xfe00);
    case 0xfea0..0xff7f: return system.io.read(addr);
    case 0xff80..0xfffe: return system.hram[addr - 0xff80];
    case 0xffff: return system.interrupts;
    default: io::printfn("Invalid read from %04x", addr); return 0x00;
  }
}

fn void System.write(System* system, UInt16 addr, UInt8 value) {
  switch(addr) {
    case 0x0000..0x00ff: 
      if (system.bios_enabled) return;
      system.cart.write(addr - 0x0000, value); 
    case 0x0100..0x7fff: system.cart.write(addr - 0x0000, value); 
    case 0x8000..0x9fff: system.ppu.write(addr - 0x8000, value);
    case 0xa000..0xbfff: system.cart.ram_write(addr - 0xa000, value);
    case 0xc000..0xdfff: system.ram[addr - 0xc000] = value;
    case 0xe000..0xfdff: system.ram[addr - 0xe000] = value;
    case 0xfe00..0xfe9f: system.ppu.oam_write(addr - 0xfe00, value);
    case 0xfea0..0xff7f: system.io.write(addr, value);
    case 0xff80..0xfffe: system.hram[addr - 0xff80] = value;
    case 0xffff: system.interrupts = value;
    default: io::printfn("Invalid write (%02x) to %04x", value, addr);
  }
}

fn UInt16 System.read16(System* system, UInt16 addr) {
  UInt16 low = system.read(addr);
  UInt16 high = system.read(addr + 1);
  return low | high << 8;
}

fn void System.write16(System* system, UInt16 addr, UInt16 value) {
  system.write(addr, (UInt8)(value & 0xFF));
  system.write(addr + 1, (UInt8)((value >> 8) & 0xFF));
}