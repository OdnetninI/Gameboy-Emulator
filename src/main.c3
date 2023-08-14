import std::io;

import types;

import inst;
import system;

fn void main(String[] args) {
  inst::init();
  system::System system;
  system.init();

  io::File! bios_file = io::file::open("roms/dmg_boot.bin", "rb");
  bios_file.read(system.bios[:256])!!;
  bios_file.close()!!;

  system.cart.open(args[1]);
  system.cart.printHeader();
  system.cart.load();

  while (true) {
    system.lcd.update();
    system.tick();
  }

  //system.lcd.close();
}