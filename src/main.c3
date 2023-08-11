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

  //io::File! game_file = io::file::open("roms/test_roms/blargg/cpu_instrs/individual/03-op sp,hl.gb", "rb");
  //io::File! game_file = io::file::open("roms/nintendo_test.gb", "rb");
  //io::File! game_file = io::file::open("roms/drmario.gb", "rb");
  //io::File! game_file = io::file::open("roms/tetris.gb", "rb");
  //io::File! game_file = io::file::open("roms/pokered.gb", "rb");
  //io::File! game_file = io::file::open("roms/hello-world.gb", "rb");
  //io::File! game_file = io::file::open("roms/test_roms/age-test-roms/m3-bg-lcdc/m3-bg-lcdc.gb", "rb");
  //io::File! game_file = io::file::open("roms/test_roms/dmg-acid2/dmg-acid2.gb", "rb");
  game_file.read(system.mem.memory[0x0000:0x8000])!!;
  game_file.close()!!;

  while (true) {
    system.lcd.update();
    system.tick();
  }

  //system.lcd.close();
}