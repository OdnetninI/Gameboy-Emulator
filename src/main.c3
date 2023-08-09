import std::io;

import types;

import lcd;
import inst;
import system;

fn void main() {
  inst::init();

  Lcd lcd;
  //lcd.init();

  system::System system;
  system.cpu.init(&system);
  system.mem.system = &system;

  io::File! bios_file = io::file::open("roms/dmg_boot.bin", "rb");
  bios_file.read(system.mem.memory[:256])!!;
  bios_file.close()!!;

  for (; system.cpu.regs.pc < 256;) {
    system.cpu.print();
    inst::Inst inst = system.cpu.fetch();
    system.cpu.exec(inst);
  }
}