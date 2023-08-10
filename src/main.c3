import std::io;

import types;

import inst;
import system;

fn void main() {
  inst::init();

  system::System system;
  system.cpu.init(&system);
  system.mem.init(&system);
  system.ppu.init(&system);
  system.lcd.init();

  io::File! bios_file = io::file::open("roms/dmg_boot.bin", "rb");
  bios_file.read(&system.mem.bios)!!;
  bios_file.close()!!;

  io::File! game_file = io::file::open("roms/tetris.gb", "rb");
  game_file.read(&system.mem.memory)!!;
  game_file.close()!!;

  while (true) {
    system.lcd.update();
    system.tick();
  }

  //system.lcd.close();
}