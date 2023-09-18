module debug;

import raylib;
import std::io;
import libc;

import types;
import system;

bool debugging_enabled = false;

UInt16 breakpoint = 0x0000;
bool breakpoint_enabled = false;

fn void checkForDebugTrigger() {
  if(raylib::is_key_pressed(raylib::keyboard::ESCAPE)) {
    io::printfn("Triggering debug (%s)", debugging_enabled);
    debugging_enabled = true;
  }
}

fn bool isDebugTriggered() {
  return debugging_enabled;
}

fn void processCMD(System* system) {
  raylib::poll_input_events(); // Hack, notify raylib that it has to update the keys

  io::printf("> ");
  String cmd = io::stdin().readline()!!;
  switch(cmd) {
    case "c": 
      debugging_enabled = false;
      io::printfn("Continuing...");
    case "quit":
      libc::exit(0);
    
    case "s":
    case "step":
    case "si":
      do {
        system.tick();
      } while (!system.cpu.cpu_executed_inst);
      io::printfn("%s", system.cpu.last_executed_inst.mnemonic)!!;
      system.cpu.print();

    case "regs":
      system.cpu.print();

    case "b":
    case "break":
      io::printf("Which Address (XXXX): ");
      String _addr = io::stdin().readline()!!;
      UInt16 addr = (UInt16)libc::strtol(_addr, null, 16);
      breakpoint = addr;
      breakpoint_enabled = true;

    case "t":
    case "trace":
      system.cpu.trace = !system.cpu.trace;
      io::printfn("CPU Tracing: %s", system.cpu.trace);

    case "r":
      io::printf("Which Address (XXXX): ");
      String _addr = io::stdin().readline()!!;
      UInt16 addr = (UInt16)libc::strtol(_addr, null, 16);
      UInt8 value = system.read(addr);
      io::printfn("%04x = %02x", addr, value);

    case "w":
      io::printf("Which Address (XXXX): ");
      String _addr = io::stdin().readline()!!;
      UInt16 addr = (UInt16)libc::strtol(_addr, null, 16);
      io::printf("Which Value (XX): ");
      String _value = io::stdin().readline()!!;
      UInt8 value = (UInt8)libc::strtol(_addr, null, 16);
      system.write(addr, value);
  }
}