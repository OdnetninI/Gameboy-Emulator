module system;

import types;

import cpu;
import mem;
import ppu;
import lcd;

struct System {
  Cpu cpu;
  Mem mem;
  Ppu ppu;
  Lcd lcd;

  UInt64 tick_counter;
}

fn void System.tick(System* system) {
  system.cpu.tick(system.tick_counter);
  system.ppu.tick(system.tick_counter);
  system.tick_counter++;
}