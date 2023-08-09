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
  Uint64 tick;
  System* system;
  bool interrupts_enabled;
}

fn void Cpu.init(Cpu* cpu, System* system) {
  cpu.system = system;
  cpu.regs.pc = 0x0000;
  cpu.interrupts_enabled = false;
}

fn inst::Inst Cpu.fetch(Cpu* cpu) {
  inst::Inst inst;

  UInt16 pc = cpu.readReg16(PC);
  UInt8 opcode = cpu.system.mem.read(pc);

  inst.pc = pc;
  inst.isCB = opcode == 0xCB;

  if (inst.isCB) {
    opcode = cpu.system.mem.read(pc + 1);
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
  io::printfn("Executing %s", inst.mnemonic)!!;
  inst.exec(cpu, &inst);

  // Apply latency and increase PC if it was not already updated
  UInt8 opcode = inst.isCB ? 0xCB : inst.opcode;
  if (inst.changedPC) {
    cpu.tick += inst::taken_latencies[opcode];
  }
  else {
    UInt16 avance = inst::inst_size[opcode];
    cpu.writeReg16(PC, pc + inst::inst_size[opcode]);
    cpu.tick += inst::latencies[opcode];
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
    case I_HL: return cpu.system.mem.read(cpu.regs.hl);
    case I_HL_MINUS: Register value = cpu.system.mem.read(cpu.regs.hl); cpu.regs.hl--; return value;
    case I_HL_PLUS: Register value = cpu.system.mem.read(cpu.regs.hl); cpu.regs.hl++; return value;
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
    case I_HL: return cpu.system.mem.write(cpu.regs.hl, value);
    case I_HL_MINUS: cpu.system.mem.write(cpu.regs.hl, value); cpu.regs.hl--;
    case I_HL_PLUS: cpu.system.mem.write(cpu.regs.hl, value); cpu.regs.hl++;
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
    case HL_MINUS: Register16 value = cpu.regs.hl; cpu.regs.hl--; return value;
    case HL_PLUS: Register16 value = cpu.regs.hl; cpu.regs.hl++; return value;
    
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
  io::printfn("%08d -> PC(%04x) SP(%04x) BC(%04x) DE(%04x) HL(%04x) AF(%04x) [Z:%s N:%s H:%s C:%s]",
              cpu.tick, cpu.regs.pc, cpu.regs.sp, cpu.regs.bc, cpu.regs.bc, cpu.regs.hl, cpu.regs.af, cpu.regs.zero, cpu.regs.neg, cpu.regs.half, cpu.regs.carry);
}