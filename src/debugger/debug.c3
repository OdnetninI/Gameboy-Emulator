module debug;

import raylib;
import std::io;
import libc;

import types;
import system;
import inst;

bool debugging_enabled = false;

enum BreakPointMode {
    NONE,
    EXEC,
    READ,
    WRITE,
    ANY
}

struct Breakpoint {
    BreakPointMode mode;
    UInt16 addr;
}

Breakpoint[16] breakpoints;
bool breakpoints_enabled = false;

bool frozen = false;
UInt16 frozen_addr = 0x0000;
UInt8 frozen_value = 0x00;

fn void initDebugger() {
  foreach (i, &b : breakpoints) {
    b.mode = NONE;
    b.addr = 0x0000;
  }
}

fn bool checkForBreakpoints(System* system, BreakPointMode mode, UInt16 addr) {
  if (!breakpoints_enabled) return false;
  foreach (i, &b : breakpoints) {
    if ((b.mode == ANY || b.mode == mode) && b.addr == addr) {
      io::printfn("Triggered %s breakpoint at address %x", mode, addr);
      inst::print_inst(system, system.cpu.regs.pc);
      debugging_enabled = true;
      return true;
    }
  }
  return false;
}

fn void checkForDebugTrigger() {
  if(raylib::is_key_pressed(raylib::keyboard::ESCAPE)) {
    io::printfn("Triggering debug (%s)", debugging_enabled);
    debugging_enabled = true;
  }
}

fn bool isDebugTriggered() {
  return debugging_enabled;
}

String last_cmd = "";

fn void processCMD(System* system) {
  raylib::poll_input_events(); // Hack, notify raylib that it has to update the keys

  io::printf("\n> ");
  String cmd = io::readline()!!;

  switch(cmd) {
    case "": break;
    default: 
      last_cmd.free();
      last_cmd = cmd;
  }

  UInt64 repeat = 1;
  do {
    repeat--;
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
        inst::print_inst(system, system.cpu.regs.pc);
        system.cpu.print3();

      case "regs":
        system.cpu.print();

      case "l":
      case "list":
        io::printfn("Breakpoints:");
        foreach (i, &b : breakpoints) {
          if (b.mode != NONE) {
            io::printfn("- %d: %s %x", i, b.mode, b.addr);
          }
        }

      case "d":
      case "del":
        io::printfn("Breakpoints:");
        foreach (i, &b : breakpoints) {
          if (b.mode != NONE) {
            io::printfn("- %d: %s %x", i, b.mode, b.addr);
          }
        }
        io::printf("Which Breakpoint?");
        String _br = io::readline()!!;
        UInt16 br = _br.to_ushort()!!;
        _br.free();
        if (br >= breakpoints.len) {
          io::printfn("Invalid breakpoint id");
          return;
        }
        breakpoints[br].mode = NONE;

      case "dela":
        foreach (i, &b : breakpoints) {
          b.mode = NONE;
          b.addr = 0x0000;
        }
        io::printfn("Deleted all breakpoints");

      case "b":
      case "break":
        io::printf("Which Address (XXXX): ");
        String _addr = io::readline()!!;
        UInt16 addr = _addr.to_ushort(16)!!;
        _addr.free();
        io::printf("Which Mode (1 Exec, 2 Read, 3 Write, 4 Any): ");
        String _mode = io::readline()!!;
        UInt16 mode = _mode.to_ushort(10)!!;
        _mode.free();
        if (mode == 0 || mode > 4) {
          io::printfn("Invalid mode");
          return;
        }
        foreach (i, &b : breakpoints) {
          if (b.mode == NONE) {
            b.mode = (BreakPointMode)mode;
            b.addr = addr;
            io::printfn("[Breakpoint:%d] Added %s on address %x", i, b.mode, b.addr);
            breakpoints_enabled = true;
            return;
          }
        }
        io::printfn("Couldn't add breakpoint, no more space, limit on %d", breakpoints.len);

      case "t":
      case "trace":
        system.cpu.trace = !system.cpu.trace;
        io::printfn("CPU Tracing: %s", system.cpu.trace);

      case "r":
        io::printf("Which Address (XXXX): ");
        String _addr = io::readline()!!;
        UInt16 addr = _addr.to_ushort(16)!!;
        _addr.free();
        UInt8 value = system.read(addr, true);
        io::printfn("%08x:%04x = %02x", system.cart.calculateAddr(addr), addr, value);

      case "w":
        io::printf("Which Address (XXXX): ");
        String _addr = io::readline()!!;
        UInt16 addr = _addr.to_ushort(16)!!;
        _addr.free();
        io::printf("Which Value (XX): ");
        String _value = io::readline()!!;
        UInt8 value = _value.to_uchar(16)!!;
        _value.free();
        system.write(addr, value, true);

      case "freeze":
        io::printf("Which Address (XXXX): ");
        String _addr = io::readline()!!;
        UInt16 addr = _addr.to_ushort(16)!!;
        _addr.free();
        io::printf("Which Value (XX): ");
        String _value = io::readline()!!;
        UInt8 value = _value.to_uchar(16)!!;
        _value.free();

        frozen = true;
        frozen_addr = addr;
        frozen_value = value;

      case "unfreeze":
        frozen = false;

      case "j":
        io::printf("Which Address (XXXX): ");
        String _addr = io::readline()!!;
        UInt16 addr = _addr.to_ushort(16)!!;
        _addr.free();
        system.cpu.regs.pc = addr;

      case "":
        repeat = 1;
        cmd = last_cmd;
    }
  } while(repeat > 0);
}
