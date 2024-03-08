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

  String bios;
  String cart;

  io::printfn("\n");
  if (args.len < 2) {
    io::printfn("Usage: %s [bios.dmg.bin] rom.gb\n", args[0]);
    return;
  } else if (args.len == 2) {
    bios = "";
    cart = args[1];
    io::printfn("- No BIOS provided, using DMG-0 integrated one\n");
    
    system.cpu.regs.a = 0x01;
    system.cpu.regs.f = 0x00;
    system.cpu.regs.b = 0xff;
    system.cpu.regs.c = 0x13;
    system.cpu.regs.d = 0x00;
    system.cpu.regs.e = 0xc1;
    system.cpu.regs.h = 0x84;
    system.cpu.regs.l = 0x03;
    system.cpu.regs.pc = 0x0100;
    system.cpu.regs.sp = 0xfffe;
  }
  else {
    bios = args[1];
    cart = args[2];
    io::printfn("- Using bios %s", bios);
  }
  
  io::printfn("- Using rom %s\n", cart);

  if (bios != "") {
    io::File! bios_file = io::file::open(args[1], "rb");
    bios_file.read(system.bios[:256])!!;
    bios_file.close()!!;
  }

  system.cart.open(cart);
  system.cart.printHeader();
  system.cart.load();

  //system.bios_enabled = false;

  while (true) {
    system.lcd.update();
    debug::checkForDebugTrigger();
    if (debug::isDebugTriggered()) {
      debug::processCMD(&system);
      system.lcd.draw_panel();
    }
    else {
      system.tick();
    }
  }

  //system.lcd.close();
}
