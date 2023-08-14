module system;

import types;

import cpu;
import mem;
import ppu;
import lcd;
import input;

struct System {
  Cpu cpu;
  Mem mem;
  Ppu ppu;
  Lcd lcd;

  UInt64 tick_counter;
  UInt16 sysclk;
}

fn void System.tick(System* system) {
  input::updateKeys(system);
  system.cpu.tick(system.tick_counter);
  system.ppu.tick(system.tick_counter);

  system.sysclk++;

  system.tick_counter++;
}