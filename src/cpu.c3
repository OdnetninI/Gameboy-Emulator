module cpu;

import types;
import inst;
import system;

import std::io;

enum Reg {
  B, C,
  D, E,
  H, L,
  F, A,
  I_HL,
  I_HL_MINUS,
  I_HL_PLUS,
}

enum Reg16 {
  BC,
  DE,
  HL,
  SP,
  AF,
  PC,
  HL_MINUS,
  HL_PLUS,
}

enum Flags {
  Z, NZ,
  N, NN,
  H, NH,
  C, NC,
  NONE,
}

enum Interrupts {
  I_NONE,
  I_VBLANK,
  I_LCD_STAT,
  I_TIMER,
  I_SERIAL,
  I_JOYPAD,
}

/* For the future !!!
macro @addRegister(b, c, bc) {
  bitstruct : Register16 @overlap {
    Register16 bc : 0..15;
    Register b : 8..15;
    Register c : 0..7;
  }
}
@addRegister(b, c, bc)
*/

struct Registers {
  bitstruct : Register16 @overlap {
    Register16 af : 0..15;
    Register a : 8..15;
    Register f : 0..7;
    bool zero : 7;
    bool neg : 6;
    bool half : 5;
    bool carry : 4;
  }
  bitstruct : Register16 @overlap {
    Register16 bc : 0..15;
    Register b : 8..15;
    Register c : 0..7;
  }
  bitstruct : Register16 @overlap {
    Register16 de : 0..15;
    Register d : 8..15;
    Register e : 0..7;
  }
  bitstruct : Register16 @overlap {
    Register16 hl : 0..15;
    Register h : 8..15;
    Register l : 0..7;
  }
  Register16 sp;
  Register16 pc;
}

struct Cpu {
  Registers regs;
  UInt64 tick_counter;
  System* system;
  bool ime;

  // For debugging
  bool cpu_executed_inst;
  Inst last_executed_inst;
  bool trace;
}

fn void Cpu.init(Cpu* cpu, System* system) {
  cpu.system = system;
  cpu.regs.pc = 0x0000;
  cpu.ime = false;

  cpu.cpu_executed_inst = false;
  cpu.trace = false;
/*
  cpu.regs.a = 0x01;
  cpu.regs.f = 0xB0;
  cpu.regs.b = 0x00;
  cpu.regs.c = 0x13;
  cpu.regs.d = 0x00;
  cpu.regs.e = 0xD8;
  cpu.regs.h = 0x01;
  cpu.regs.l = 0x4D;
  cpu.regs.sp = 0xfffe;
  cpu.regs.pc = 0x0100;*/
}

fn void Cpu.tick(Cpu* cpu, UInt64 tick) {
  if (cpu.ime) {
    Interrupts interrupt = cpu.getInterrupt();
    cpu.interrupt(interrupt);
  }
  if (tick >= cpu.tick_counter) {
    if (cpu.trace) cpu.print();
    //cpu.print();
    //cpu.print2();
    inst::Inst inst = cpu.fetch();
    cpu.exec(inst);

    cpu.last_executed_inst = inst;
    cpu.cpu_executed_inst = true;
  }
  else {
    cpu.cpu_executed_inst = false;
  }  
}

fn Interrupts Cpu.getInterrupt(Cpu* cpu) {
  UInt8 _if = cpu.system.read(0xFF0F);
  if ((_if & (1 << 0)) != 0x00) return I_VBLANK;
  if ((_if & (1 << 1)) != 0x00) return I_LCD_STAT;
  if ((_if & (1 << 2)) != 0x00) return I_TIMER;
  if ((_if & (1 << 3)) != 0x00) return I_SERIAL;
  if ((_if & (1 << 4)) != 0x00) return I_JOYPAD;
  return I_NONE;
}

fn void Cpu.interrupt(Cpu* cpu, Interrupts interrupt) {
  UInt8 _if = cpu.system.read(0xFF0F);
  switch(interrupt) {
    case I_NONE: return;
    case I_VBLANK: _if = _if & (char)~(1 << 0);
    case I_LCD_STAT: _if = _if & (char)~(1 << 1);
    case I_TIMER: _if = _if & (char)~(1 << 2);
    case I_SERIAL: _if = _if & (char)~(1 << 3);
    case I_JOYPAD: _if = _if & (char)~(1 << 4);
  }
  cpu.system.write(0xFF0F, _if);

  UInt8 ie = cpu.system.read(0xFFFF);
  switch(interrupt) {
    case I_NONE: return;
    case I_VBLANK:
      if ((ie & (1 << 0)) == 0x00) return;
    case I_LCD_STAT:
      if ((ie & (1 << 1)) == 0x00) return;
    case I_TIMER:
      if ((ie & (1 << 2)) == 0x00) return;
    case I_SERIAL:
      if ((ie & (1 << 3)) == 0x00) return;
    case I_JOYPAD:
      if ((ie & (1 << 4)) == 0x00) return;
  }
  //io::printfn("Doing %s", interrupt);
  cpu.ime = false;
  cpu.tick_counter += 2;
  inst::push16(cpu, null, cpu.regs.pc);
  cpu.tick_counter += 2;
  switch(interrupt) {
    case I_VBLANK: cpu.regs.pc = 0x0040;
    case I_LCD_STAT: cpu.regs.pc = 0x0048;
    case I_TIMER: cpu.regs.pc = 0x0050;
    case I_SERIAL: cpu.regs.pc = 0x0058;
    case I_JOYPAD: cpu.regs.pc = 0x0060;
    default: io::printfn("Invalid interrupt");
  }
  cpu.tick_counter += 1;
}

fn inst::Inst Cpu.fetch(Cpu* cpu) {
  inst::Inst inst;

  UInt16 pc = cpu.readReg16(PC);
  UInt8 opcode = cpu.system.read(pc);

  inst.pc = pc;
  inst.isCB = opcode == 0xCB;

  if (inst.isCB) {
    opcode = cpu.system.read(pc + 1);
    inst.mnemonic = inst::mnemonics_CB[opcode];
    inst.exec = inst::functions_CB[opcode];
  }
  else {
    inst.mnemonic = inst::mnemonics[opcode];
    inst.exec = inst::functions[opcode];
  }

  inst.opcode = opcode;
  inst.changedPC = false;


  return inst;
}

fn void Cpu.exec(Cpu* cpu, inst::Inst inst) {
  UInt16 pc = cpu.readReg16(PC);
  if (cpu.trace) io::printfn("Executing %s", inst.mnemonic)!!;
  //io::printfn("Executing %s", inst.mnemonic)!!;
  inst.exec(cpu, &inst);

  // Apply latency and increase PC if it was not already updated
  UInt8 opcode = inst.isCB ? 0xCB : inst.opcode;
  if (inst.changedPC) {
    cpu.tick_counter += inst::taken_latencies[opcode];
  }
  else {
    UInt16 avance = inst::inst_size[opcode];
    cpu.writeReg16(PC, pc + inst::inst_size[opcode]);
    cpu.tick_counter += inst::latencies[opcode];
  }
}

/*
  Register manipulation
*/
fn Register Cpu.readReg(Cpu* cpu, Reg reg) {
  switch(reg) {
    case B: return cpu.regs.b;
    case C: return cpu.regs.c;
    case D: return cpu.regs.d;
    case E: return cpu.regs.e;
    case H: return cpu.regs.h;
    case L: return cpu.regs.l;
    case F: return cpu.regs.f;
    case A: return cpu.regs.a;
    case I_HL: return cpu.system.read(cpu.regs.hl);
    case I_HL_MINUS: Register value = cpu.system.read(cpu.regs.hl); cpu.regs.hl-= 1; return value;
    case I_HL_PLUS: Register value = cpu.system.read(cpu.regs.hl); cpu.regs.hl+= 1; return value;
    default: 
      io::printfn("[CPU] Cannot read unkwown registr %d", reg);
      return 0;
  }
}

fn void Cpu.writeReg(Cpu* cpu, Reg reg, Register value) {
  switch(reg) {
    case B: cpu.regs.b = value;
    case C: cpu.regs.c = value;
    case D: cpu.regs.d = value;
    case E: cpu.regs.e = value;
    case H: cpu.regs.h = value;
    case L: cpu.regs.l = value;
    case F: cpu.regs.f = value;
    case A: cpu.regs.a = value;
    case I_HL: return cpu.system.write(cpu.regs.hl, value);
    case I_HL_MINUS: cpu.system.write(cpu.regs.hl, value); cpu.regs.hl-= 1;
    case I_HL_PLUS: cpu.system.write(cpu.regs.hl, value); cpu.regs.hl+= 1;
    default: 
      io::printfn("[CPU] Cannot write %02x unkwown registr %d", value, reg);
  }
}

fn Register16 Cpu.readReg16(Cpu* cpu, Reg16 reg) {
  switch(reg) {
    case BC: return cpu.regs.bc;
    case DE: return cpu.regs.de;
    case HL: return cpu.regs.hl;
    case SP: return cpu.regs.sp;
    case AF: return cpu.regs.af;
    case PC: return cpu.regs.pc;
    case HL_MINUS: Register16 value = cpu.regs.hl; cpu.regs.hl -= 1; return value;
    case HL_PLUS: Register16 value = cpu.regs.hl; cpu.regs.hl += 1; return value;
    
    default: 
      io::printfn("[CPU] Cannot read16 unkwown registr %d", reg);
      return 0;
  }
}

fn void Cpu.writeReg16(Cpu* cpu, Reg16 reg, Register16 value) {
  switch(reg) {
    case BC: cpu.regs.bc = value;
    case DE: cpu.regs.de = value;
    case HL: cpu.regs.hl = value;
    case SP: cpu.regs.sp = value;
    case AF: cpu.regs.af = value;
    case PC: cpu.regs.pc = value;
    default: 
      io::printfn("[CPU] Cannot write %04x unkwown registr %d", value, reg);
  }
}

fn bool Cpu.readFlag(Cpu* cpu, Flags flag) {
  switch(flag) {
    case Z: return cpu.regs.zero;
    case NZ: return !cpu.regs.zero;
    case N: return cpu.regs.neg;
    case NN: return !cpu.regs.neg;
    case H: return cpu.regs.half;
    case NH: return !cpu.regs.half;
    case C: return cpu.regs.carry;
    case NC: return !cpu.regs.carry;
    case NONE: return true;
    default: 
      io::printfn("[CPU] Cannot read unkwown flag %d", flag);
      return false;
  }
}

fn void Cpu.setFlags(Cpu* cpu, bool zero, bool neg, bool half, bool carry) {
  cpu.regs.zero = zero;
  cpu.regs.neg = neg;
  cpu.regs.half = half;
  cpu.regs.carry = carry;
}

/*
  Print the current state
*/
fn void Cpu.print(Cpu* cpu) {
  io::printfn("%08d -> PC(%04x) SP(%04x) BC(%04x) DE(%04x) HL(%04x) AF(%04x) [Z:%s N:%s H:%s C:%s IME:%s]",
              cpu.tick_counter, cpu.regs.pc, cpu.regs.sp, cpu.regs.bc, cpu.regs.de, cpu.regs.hl, cpu.regs.af, cpu.regs.zero, cpu.regs.neg, cpu.regs.half, cpu.regs.carry, cpu.ime);
}
fn void Cpu.print2(Cpu* cpu) {
  io::printfn("A:%02X F:%02X B:%02X C:%02X D:%02X E:%02X H:%02X L:%02X SP:%04X PC:%04X PCMEM:%02X,%02X,%02X,%02X",
              cpu.regs.a, cpu.regs.f, cpu.regs.b, cpu.regs.c, cpu.regs.d, cpu.regs.e, cpu.regs.h, cpu.regs.l, cpu.regs.sp, cpu.regs.pc,
              cpu.system.read(cpu.regs.pc),cpu.system.read(cpu.regs.pc+1),cpu.system.read(cpu.regs.pc+2),cpu.system.read(cpu.regs.pc+3));
}