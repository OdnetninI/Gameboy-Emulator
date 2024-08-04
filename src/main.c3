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

    system.write(0xff00, 0xcf, true);
    system.write(0xff01, 0x00, true);
    system.write(0xff02, 0x7e, true);
    system.write(0xff04, 0x18, true);
    system.write(0xff05, 0x00, true);
    system.write(0xff06, 0x00, true);
    system.write(0xff07, 0xf8, true);
    system.write(0xff0f, 0xe1, true);
    system.write(0xff40, 0x91, true);
    system.write(0xff41, 0x81, true);
    system.write(0xff42, 0x00, true);
    system.write(0xff43, 0x00, true);
    system.write(0xff44, 0x91, true);
    system.write(0xff45, 0x00, true);
    system.write(0xff46, 0xff, true);
    system.write(0xff47, 0xfc, true);
    system.write(0xff4a, 0x00, true);
    system.write(0xff4b, 0x00, true);
    system.write(0xffff, 0x00, true);
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
