import std::io;

import types;

import inst;
import system;
import debug;

fn void main(String[] args) {
  inst::init();
  system::System system;
  system.serial.disconected = !(args.len >= 5);
  if (args.len >= 5) {
    system.serial.master = (args[3][0] == 'S');
    system.serial.port = args[4];
  }

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
    debug::checkForDebugTrigger();
    if (debug::isDebugTriggered()) {
      debug::processCMD(&system);
    }
    else {
      system.tick();
    }
  }

  //system.lcd.close();
}