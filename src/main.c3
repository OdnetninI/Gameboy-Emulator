import std::io;

import types;

import inst;
import system;

fn void main(String[] args) {
  inst::init();
  system::System system;
  system.init();

  io::File! bios_file = io::file::open(args[1], "rb");
  bios_file.read(system.bios[:256])!!;
  bios_file.close()!!;

  system.cart.open(args[2]);
  system.cart.printHeader();
  system.cart.load();

  //system.bios_enabled = false;

  while (true) {
    system.lcd.update();
    system.tick();
  }

  //system.lcd.close();
}