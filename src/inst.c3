module inst;

import types;
import cpu;
import system;

import std::io;

// Prototype for inst exec function
def InstExec = fn void(Cpu*, Inst*);

// Instruction
struct Inst {
  UInt16 pc;
  UInt8 opcode;
  bool isCB;
  String mnemonic;
  bool changedPC;
  InstExec exec;
}

fn void push16(Cpu* cpu, Inst* inst, UInt16 value) {
  UInt16 stack_addr = cpu.readReg16(SP);
  stack_addr -= 2;
  cpu.system.write16(stack_addr, value);
  cpu.writeReg16(SP, stack_addr);
}

fn UInt16 pop16(Cpu* cpu, Inst* inst) {
  UInt16 stack_addr = cpu.readReg16(SP);
  UInt16 value = cpu.system.read16(stack_addr);
  stack_addr += 2;
  cpu.writeReg16(SP, stack_addr);
  return value;
}

// Default behaviour
fn void opcode_unimplemented(Cpu* cpu, Inst* inst) {
  io::printfn("Function of opcode %s%02x not implemented", inst.isCB ? "CB " : "", inst.opcode)!!;
}

fn void nop(Cpu* cpu, Inst* inst) { ; }

fn void stop(Cpu* cpu, Inst* inst) {
  io::printfn("Bizarre STOP instruction...");
  // More info at https://gbdev.io/pandocs/imgs/gb_stop.png
  // Let's do a simple version with halt but enabling the keys
  cpu.system.write(0xFF00, 0x10);
  cpu.halted = true;
  // Still a lot of work about glitches, DIV counter and Clock Speeds
}

fn void halt(Cpu* cpu, Inst* inst) {
  cpu.halted = true;
  //io::printfn("Starting a CPU halt...");
}

// Generic methods
fn void cmpRegImm(Cpu* cpu, Inst* inst, Reg _data) {
  UInt8 data = cpu.readReg(_data);
  UInt8 cmp = cpu.system.read(inst.pc + 1);
  cpu.setFlags(data == cmp, true, (data & 0x0F) < (cmp & 0xF), data < cmp);
}

fn void cmpRegReg(Cpu* cpu, Inst* inst, Reg _data, Reg _cmp) {
  UInt8 data = cpu.readReg(_data);
  UInt8 cmp = cpu.readReg(_cmp);
  cpu.setFlags(data == cmp, true, (data & 0x0F) < (cmp & 0xF), data < cmp);
}

fn void addRegReg(Cpu* cpu, Inst* inst, Reg _dest, Reg _src) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.readReg(_src);
  UInt8 value = dest + src;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, ((dest & 0x0F) + (src & 0xF)) > 0x0F, (value < dest) || (value < src));
}

fn void adcRegReg(Cpu* cpu, Inst* inst, Reg _dest, Reg _src) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.readReg(_src);
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  UInt8 value = dest + src + carry;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, ((dest & 0x0F) + (src & 0xF) + carry) > 0x0F, (value < (dest + carry)) || (value < (src + carry)));
}

fn void adcRegImm8(Cpu* cpu, Inst* inst, Reg _dest) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.system.read(inst.pc + 1);
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  UInt8 value = dest + src + carry;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, ((dest & 0x0F) + (src & 0x0F) + carry) > 0x0F, (value < (dest + carry)) || (value < (src + carry)));
}

fn void addReg16Reg16(Cpu* cpu, Inst* inst, Reg16 _dest, Reg16 _src) {
  UInt16 dest = cpu.readReg16(_dest);
  UInt16 src = cpu.readReg16(_src);
  UInt16 value = dest + src;
  cpu.writeReg16(_dest, value);
  cpu.setFlags(cpu.readFlag(Z), false, ((dest & 0x0FFF) + (src & 0x0FFF)) > 0x0FFF, (value < src) || (value < dest));
}

fn void addReg16Imm8(Cpu* cpu, Inst* inst, Reg16 _dest) {
  UInt16 dest = cpu.readReg16(_dest);
  Int8 src = cpu.system.read(inst.pc + 1);
  UInt16 value = dest + src;
  cpu.writeReg16(_dest, value);

  bool carry = ((value & 0xFF) < src) || ((value & 0xff) < (dest & 0xff));
  if (src < 0) carry = (value & 0xff) <= (dest & 0xff);

  cpu.setFlags(false, false, ((dest & 0x0F) + (src & 0x0F)) > 0x0F, carry);
}

fn void reg162Reg16(Cpu* cpu, Inst* inst, Reg16 _dest, Reg16 _src) {
  UInt16 src = cpu.readReg16(_src);
  cpu.writeReg16(_dest, src);
}

fn void reg162Reg16addImm8(Cpu* cpu, Inst* inst, Reg16 _dest, Reg16 _src) {
  UInt16 src = cpu.readReg16(_src);
  Int8 offset = cpu.system.read(inst.pc + 1);
  UInt16 value = src + offset;
  cpu.writeReg16(_dest, value);
  
  bool carry = ((value & 0xFF) < offset) || ((value & 0xff) < (src & 0xff));
  if (offset < 0) carry = (value & 0xff) <= (src & 0xff);

  cpu.setFlags(false, false, ((src & 0x0F) + (offset & 0x0F)) > 0x0F, carry);
}

fn void addRegImm8(Cpu* cpu, Inst* inst, Reg _dest) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.system.read(inst.pc + 1);
  UInt8 value = dest + src;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, ((dest & 0x0F) + (src & 0xF)) > 0x0F, (value < dest) || (value < src));
}

fn void andRegReg(Cpu* cpu, Inst* inst, Reg _dest, Reg _src) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.readReg(_src);
  UInt8 value = dest & src;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, true, false);
}

fn void andRegImm(Cpu* cpu, Inst* inst, Reg _dest) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.system.read(inst.pc + 1);
  UInt8 value = dest & src;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, true, false);
}

fn void orRegReg(Cpu* cpu, Inst* inst, Reg _dest, Reg _src) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.readReg(_src);
  UInt8 value = dest | src;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, false, false);
}

fn void orRegImm8(Cpu* cpu, Inst* inst, Reg _dest) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.system.read(inst.pc + 1);
  UInt8 value = dest | src;
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, false, false, false);
}

fn void subRegReg(Cpu* cpu, Inst* inst, Reg _dest, Reg _src) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.readReg(_src);
  cpu.writeReg(_dest, dest - src);
  cpu.setFlags(dest == src, true, (dest & 0x0F) < (src & 0xF), dest < src);
}

fn void subRegImm8(Cpu* cpu, Inst* inst, Reg _dest) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 src = cpu.system.read(inst.pc + 1);
  cpu.writeReg(_dest, dest - src);
  cpu.setFlags(dest == src, true, (dest & 0x0F) < (src & 0xF), dest < src);
}

fn void sbcRegReg(Cpu* cpu, Inst* inst, Reg _dest, Reg _src) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  UInt8 src = cpu.readReg(_src);
  UInt8 value = dest - (src + carry);
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, true, (Int8)((dest & 0xF) - (src & 0xF) - carry) < 0, dest < (src + carry));
}

fn void sbcRegImm8(Cpu* cpu, Inst* inst, Reg _dest) {
  UInt8 dest = cpu.readReg(_dest);
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  UInt8 src = cpu.system.read(inst.pc + 1);
  UInt8 value = dest - (src + carry);
  cpu.writeReg(_dest, value);
  cpu.setFlags(value == 0x00, true, (Int8)((dest & 0xF) - (src & 0xF) - carry) < 0, dest < (src + carry));
}

fn void setInterrupts(Cpu* cpu, Inst* inst, bool enabled) {
  //io::printfn("%s Interruptions", enabled ? "Enabling" : "Disabling");
  cpu.ime = enabled;
}

fn void pushReg16(Cpu* cpu, Inst* inst, Reg16 reg) {
  UInt16 value = cpu.readReg16(reg);
  push16(cpu, inst, value);
}

fn void popReg16(Cpu* cpu, Inst* inst, Reg16 reg) {
  UInt16 value = pop16(cpu, inst);
  if (reg == AF) value = value & 0xFFF0;
  cpu.writeReg16(reg, value);
}

fn void reg2Reg(Cpu* cpu, Inst* inst, Reg dest, Reg src) {
  UInt8 data = cpu.readReg(src);
  cpu.writeReg(dest, data);
}

fn void imm2Reg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt16 imm_addr = inst.pc + 1;
  UInt8 imm = cpu.system.read(imm_addr);
  cpu.writeReg(reg, imm);
}

fn void reg162MemImm16(Cpu* cpu, Inst* inst, Reg16 reg) {
  UInt16 addr = cpu.system.read16(inst.pc + 1);
  UInt16 data = cpu.readReg16(reg);
  cpu.system.write16(addr, data);
}

fn void memReg2Reg(Cpu* cpu, Inst* inst, Reg reg, Reg16 _addr) {
  UInt16 addr = cpu.readReg16(_addr);
  UInt8 value = cpu.system.read(addr);
  cpu.writeReg(reg, value);
}

fn void reg2MemReg16(Cpu* cpu, Inst* inst, Reg reg, Reg16 _addr) {
  UInt16 addr = cpu.readReg16(_addr);
  UInt8 value = cpu.readReg(reg);
  cpu.system.write(addr, value);
}

fn void reg2MemImm8(Cpu* cpu, Inst* inst, Reg reg, UInt16 mem) {
  UInt16 imm_addr = inst.pc + 1;
  UInt8 offset = cpu.system.read(imm_addr);
  UInt8 data = cpu.readReg(reg);
  cpu.system.write(mem + offset, data);
}

fn void memImm82Reg(Cpu* cpu, Inst* inst, Reg reg, UInt16 mem) {
  UInt16 imm_addr = inst.pc + 1;
  UInt8 offset = cpu.system.read(imm_addr);
  UInt8 data = cpu.system.read(mem + offset);
  cpu.writeReg(reg, data);
}

fn void reg2MemImm(Cpu* cpu, Inst* inst, Reg reg) {
  UInt16 imm_addr = inst.pc + 1;
  UInt16 addr = cpu.system.read16(imm_addr);
  UInt8 data = cpu.readReg(reg);
  cpu.system.write(addr, data);
}

fn void memImm2Reg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt16 imm_addr = inst.pc + 1;
  UInt16 addr = cpu.system.read16(imm_addr);
  UInt8 data = cpu.system.read(addr);
  cpu.writeReg(reg, data);
  
}

fn void reg2MemReg(Cpu* cpu, Inst* inst, Reg _data, Reg _offset, UInt16 mem) {
  UInt8 offset = cpu.readReg(_offset);
  UInt8 data = cpu.readReg(_data);
  cpu.system.write(mem + offset, data);
}

fn void memRegOff2Reg(Cpu* cpu, Inst* inst, Reg _data, Reg _offset, UInt16 mem) {
  UInt8 offset = cpu.readReg(_offset);
  UInt8 data = cpu.system.read(mem + offset);
  cpu.writeReg(_data, data);
}

fn void imm2Reg16(Cpu* cpu, Inst* inst, Reg16 reg) {
  UInt16 imm_addr = inst.pc + 1;
  UInt16 imm = cpu.system.read16(imm_addr);
  cpu.writeReg16(reg, imm);
}

fn void reg2reg(Cpu* cpu, Inst* inst, Reg dest, Reg src) {
  UInt8 value = cpu.readReg(src);
  cpu.writeReg(dest, value);
}

fn void xorReg(Cpu* cpu, Inst* inst, Reg dest, Reg src) {
  UInt8 value = cpu.readReg(dest);
  UInt8 xorvalue = cpu.readReg(src);
  UInt8 result = value ^ xorvalue;
  cpu.writeReg(dest, result);
  cpu.setFlags(result == 0x00, false, false, false);
}

fn void xorRegImm8(Cpu* cpu, Inst* inst, Reg dest) {
  UInt8 value = cpu.readReg(dest);
  UInt8 xorvalue = cpu.system.read(inst.pc + 1);
  UInt8 result = value ^ xorvalue;
  cpu.writeReg(dest, result);
  cpu.setFlags(result == 0x00, false, false, false);
}

fn void cplReg(Cpu* cpu, Inst* inst, Reg dest) {
  UInt8 value = cpu.readReg(dest);
  UInt8 result = ~value;
  cpu.writeReg(dest, result);
  cpu.setFlags(cpu.readFlag(Z), true, true, cpu.readFlag(C));
}

fn void swapReg(Cpu* cpu, Inst* inst, Reg dest) {
  UInt8 value = cpu.readReg(dest);
  UInt8 result = ((value >> 4) & 0x0F) | ((value << 4) & 0xF0);
  cpu.writeReg(dest, result);
  cpu.setFlags(result == 0x00, false, false, false);
}

fn void jumpImmRel(Cpu* cpu, Inst* inst, Flags flag) {
  bool jump = cpu.readFlag(flag);
  if (jump) {
    inst.changedPC = true;
    UInt16 pc = inst.pc + inst_size[inst.opcode];
    Int8 imm = cpu.system.read(inst.pc + 1);
    cpu.writeReg16(PC, pc + imm);
  }
}

fn void jumpImm(Cpu* cpu, Inst* inst, Flags flag) {
  bool jump = cpu.readFlag(flag);
  if (jump) {
    inst.changedPC = true;
    UInt16 newpc = cpu.system.read16(inst.pc + 1);
    cpu.writeReg16(PC, newpc);
  }
}

fn void jumpReg(Cpu* cpu, Inst* inst, Reg16 dest) {
  inst.changedPC = true;
  UInt16 newpc = cpu.readReg16(dest);
  cpu.writeReg16(PC, newpc);
}

fn void callImm(Cpu* cpu, Inst* inst, Flags flag) {
  bool jump = cpu.readFlag(flag);
  if (jump) {
    inst.changedPC = true;
    push16(cpu, inst, inst.pc + inst_size[inst.opcode]);
    UInt16 new_pc = cpu.system.read16(inst.pc + 1);
    cpu.writeReg16(PC, new_pc);
  }
}

fn void ret(Cpu* cpu, Inst* inst, Flags flag) {
  bool jump = cpu.readFlag(flag);
  if (jump) {
    inst.changedPC = true;
    UInt16 new_pc = pop16(cpu, inst);
    cpu.writeReg16(PC, new_pc);
  }
}

fn void reti(Cpu* cpu, Inst* inst) {
  inst.changedPC = true;
  UInt16 new_pc = pop16(cpu, inst);
  cpu.writeReg16(PC, new_pc);
  cpu.ime = true;
}

fn void rst(Cpu* cpu, Inst* inst, UInt16 addr) {
  inst.changedPC = true;
  push16(cpu, inst, inst.pc + inst_size[inst.opcode]);
  cpu.writeReg16(PC, addr);
}

fn void incReg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 data = cpu.readReg(reg);
  UInt8 new_data = data + 1;
  cpu.writeReg(reg, new_data);
  cpu.setFlags(new_data == 0x00, false, ((data & 0x0F)+1) == 0x10, cpu.regs.carry);
}

fn void decReg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 data = cpu.readReg(reg);
  UInt8 new_data = data - 1;
  cpu.writeReg(reg, new_data);
  cpu.setFlags(new_data == 0x00, true, (((data & 0x0F)-1) & 0xFF) == 0xFF, cpu.regs.carry);
}

fn void incReg16(Cpu* cpu, Inst* inst, Reg16 reg) {
  UInt16 data = cpu.readReg16(reg);
  data++;
  cpu.writeReg16(reg, data);
}

fn void decReg16(Cpu* cpu, Inst* inst, Reg16 reg) {
  UInt16 data = cpu.readReg16(reg);
  data--;
  cpu.writeReg16(reg, data);
}

fn void bitReg(Cpu* cpu, Inst* inst, Reg reg, UInt8 bit) {
  UInt8 value = cpu.readReg(reg);
  UInt8 test = (1 << bit);
  cpu.setFlags(value & test == 0x00, false, true, cpu.regs.carry);
}

fn void resBitReg(Cpu* cpu, Inst* inst, Reg reg, UInt8 bit) {
  UInt8 value = cpu.readReg(reg);
  UInt8 mask = ~(1 << bit);
  UInt8 result = value & mask;
  cpu.writeReg(reg, result);
}

fn void setBitReg(Cpu* cpu, Inst* inst, Reg reg, UInt8 bit) {
  UInt8 value = cpu.readReg(reg);
  UInt8 set = (1 << bit);
  UInt8 result = value | set;
  cpu.writeReg(reg, result);
}

fn void sraReg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = value & 0x1;
  UInt8 result = (value >> 1) | (value & 0x80);
  cpu.writeReg(reg, result);
  cpu.setFlags(result == 0x00, false, false, new_carry == 0x1);
}

fn void srlReg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = value & 0x1;
  UInt8 result = (value >> 1) & 0x7F;
  cpu.writeReg(reg, result);
  cpu.setFlags(result == 0x00, false, false, new_carry == 0x1);
}


fn void slaReg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = (value >> 7) & 0x1;
  UInt8 result = (value << 1) & 0xFE;
  cpu.writeReg(reg, result);
  cpu.setFlags(result == 0x00, false, false, new_carry == 0x1);
}

fn void daaReg(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);

  bool carry = cpu.readFlag(C);
  bool half = cpu.readFlag(H);
  bool neg = cpu.readFlag(N);

  if (neg) {
    if (carry) {
      value -= 0x60;
    }
    if (half) {
      value -= 0x6;
    }
  }
  else {
    if (carry || value > 0x99) {
      carry = true;
      value += 0x60;
    }
    if (half || ((value & 0x0F) > 0x09)) {
      value += 0x06;
    }
  }

  cpu.writeReg(reg, value);
  cpu.setFlags(value == 0x00, neg, false, carry);
}

fn void scf(Cpu* cpu, Inst* inst) {
  bool zero = cpu.readFlag(Z);
  cpu.setFlags(zero, false, false, true);
}

fn void ccf(Cpu* cpu, Inst* inst) {
  bool zero = cpu.readFlag(Z);
  bool carry = cpu.readFlag(C);
  cpu.setFlags(zero, false, false, !carry);
}

// RLC
fn void rotateLeft(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 carry = value >> 7;
  value = value << 1;
  value += carry;
  cpu.writeReg(reg, value);
  cpu.setFlags(value == 0x00, false, false, carry == 0x01);
}

fn void rotateRight(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 carry = value & 0x1;
  value = value >> 1 | (carry << 7);
  cpu.writeReg(reg, value);
  cpu.setFlags(value == 0x00, false, false, carry == 0x01);
}

fn void rotateLeftNOZ(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 carry = value >> 7;
  value = value << 1;
  value += carry;
  cpu.writeReg(reg, value);
  cpu.setFlags(false, false, false, carry == 0x01);
}

fn void rotateRightNOZ(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 carry = value & 0x1;
  value = value >> 1 | (carry << 7);
  cpu.writeReg(reg, value);
  cpu.setFlags(false, false, false, carry == 0x01);
}

// RL
fn void rotateLeftWithCarry(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = value >> 7;
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  value = value << 1;
  value += carry;
  cpu.writeReg(reg, value);
  cpu.setFlags(value == 0x00, false, false, new_carry == 0x01);
}

fn void rotateRightWithCarry(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = value & 0x1;
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  value = (value >> 1) | (carry << 7);
  cpu.writeReg(reg, value);
  cpu.setFlags(value == 0x00, false, false, new_carry == 0x01);
}

fn void rotateLeftWithCarryNOZ(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = value >> 7;
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  value = value << 1;
  value += carry;
  cpu.writeReg(reg, value);
  cpu.setFlags(false, false, false, new_carry == 0x01);
}

fn void rotateRightWithCarryNOZ(Cpu* cpu, Inst* inst, Reg reg) {
  UInt8 value = cpu.readReg(reg);
  UInt8 new_carry = value & 0x1;
  UInt8 carry = cpu.readFlag(C) ? 1 : 0;
  value = (value >> 1) | (carry << 7);
  cpu.writeReg(reg, value);
  cpu.setFlags(false, false, false, new_carry == 0x01);
}

// Instructions
InstExec[256] functions;
InstExec[256] functions_CB;

fn void init() {
  functions[0..255] = &opcode_unimplemented;
  functions_CB[0..255] = &opcode_unimplemented;

  /* Insts */
  functions[0x00] = fn (cpu, inst) => nop(cpu, inst);
  functions[0x01] = fn (cpu, inst) => imm2Reg16(cpu, inst, BC);
  functions[0x02] = fn (cpu, inst) => reg2MemReg16(cpu, inst, A, BC);
  functions[0x03] = fn (cpu, inst) => incReg16(cpu, inst, BC);
  functions[0x04] = fn (cpu, inst) => incReg(cpu, inst, B);
  functions[0x05] = fn (cpu, inst) => decReg(cpu, inst, B);
  functions[0x06] = fn (cpu, inst) => imm2Reg(cpu, inst, B);
  functions[0x07] = fn (cpu, inst) => rotateLeftNOZ(cpu, inst, A);
  functions[0x08] = fn (cpu, inst) => reg162MemImm16(cpu, inst, SP);
  functions[0x09] = fn (cpu, inst) => addReg16Reg16(cpu, inst, HL, BC);
  functions[0x0a] = fn (cpu, inst) => memReg2Reg(cpu, inst, A, BC);
  functions[0x0b] = fn (cpu, inst) => decReg16(cpu, inst, BC);
  functions[0x0c] = fn (cpu, inst) => incReg(cpu, inst, C);
  functions[0x0d] = fn (cpu, inst) => decReg(cpu, inst, C);
  functions[0x0e] = fn (cpu, inst) => imm2Reg(cpu, inst, C);
  functions[0x0f] = fn (cpu, inst) => rotateRightNOZ(cpu, inst, A);

  functions[0x10] = fn (cpu, inst) => stop(cpu, inst);
  functions[0x11] = fn (cpu, inst) => imm2Reg16(cpu, inst, DE);
  functions[0x12] = fn (cpu, inst) => reg2MemReg16(cpu, inst, A, DE);
  functions[0x13] = fn (cpu, inst) => incReg16(cpu, inst, DE);
  functions[0x14] = fn (cpu, inst) => incReg(cpu, inst, D);
  functions[0x15] = fn (cpu, inst) => decReg(cpu, inst, D);
  functions[0x16] = fn (cpu, inst) => imm2Reg(cpu, inst, D);
  functions[0x17] = fn (cpu, inst) => rotateLeftWithCarryNOZ(cpu, inst, A);
  functions[0x18] = fn (cpu, inst) => jumpImmRel(cpu, inst, NONE);
  functions[0x19] = fn (cpu, inst) => addReg16Reg16(cpu, inst, HL, DE);
  functions[0x1a] = fn (cpu, inst) => memReg2Reg(cpu, inst, A, DE);
  functions[0x1b] = fn (cpu, inst) => decReg16(cpu, inst, DE);
  functions[0x1c] = fn (cpu, inst) => incReg(cpu, inst, E);
  functions[0x1d] = fn (cpu, inst) => decReg(cpu, inst, E);
  functions[0x1e] = fn (cpu, inst) => imm2Reg(cpu, inst, E);
  functions[0x1f] = fn (cpu, inst) => rotateRightWithCarryNOZ(cpu, inst, A);

  functions[0x20] = fn (cpu, inst) => jumpImmRel(cpu, inst, NZ);
  functions[0x21] = fn (cpu, inst) => imm2Reg16(cpu, inst, HL);
  functions[0x22] = fn (cpu, inst) => reg2MemReg16(cpu, inst, A, HL_PLUS);
  functions[0x23] = fn (cpu, inst) => incReg16(cpu, inst, HL);
  functions[0x24] = fn (cpu, inst) => incReg(cpu, inst, H);
  functions[0x25] = fn (cpu, inst) => decReg(cpu, inst, H);
  functions[0x26] = fn (cpu, inst) => imm2Reg(cpu, inst, H);
  functions[0x27] = fn (cpu, inst) => daaReg(cpu, inst, A);
  functions[0x28] = fn (cpu, inst) => jumpImmRel(cpu, inst, Z);
  functions[0x29] = fn (cpu, inst) => addReg16Reg16(cpu, inst, HL, HL);
  functions[0x2a] = fn (cpu, inst) => memReg2Reg(cpu, inst, A, HL_PLUS);
  functions[0x2b] = fn (cpu, inst) => decReg16(cpu, inst, HL);
  functions[0x2c] = fn (cpu, inst) => incReg(cpu, inst, L);
  functions[0x2d] = fn (cpu, inst) => decReg(cpu, inst, L);
  functions[0x2e] = fn (cpu, inst) => imm2Reg(cpu, inst, L);
  functions[0x2f] = fn (cpu, inst) => cplReg(cpu, inst, A);

  functions[0x30] = fn (cpu, inst) => jumpImmRel(cpu, inst, NC);
  functions[0x31] = fn (cpu, inst) => imm2Reg16(cpu, inst, SP);
  functions[0x32] = fn (cpu, inst) => reg2MemReg16(cpu, inst, A, HL_MINUS);
  functions[0x33] = fn (cpu, inst) => incReg16(cpu, inst, SP);
  functions[0x34] = fn (cpu, inst) => incReg(cpu, inst, I_HL);
  functions[0x35] = fn (cpu, inst) => decReg(cpu, inst, I_HL);
  functions[0x36] = fn (cpu, inst) => imm2Reg(cpu, inst, I_HL);
  functions[0x37] = fn (cpu, inst) => scf(cpu, inst);
  functions[0x38] = fn (cpu, inst) => jumpImmRel(cpu, inst, C);
  functions[0x39] = fn (cpu, inst) => addReg16Reg16(cpu, inst, HL, SP);
  functions[0x3a] = fn (cpu, inst) => memReg2Reg(cpu, inst, A, HL_MINUS);
  functions[0x3b] = fn (cpu, inst) => decReg16(cpu, inst, SP);
  functions[0x3c] = fn (cpu, inst) => incReg(cpu, inst, A);
  functions[0x3d] = fn (cpu, inst) => decReg(cpu, inst, A);
  functions[0x3e] = fn (cpu, inst) => imm2Reg(cpu, inst, A);
  functions[0x3f] = fn (cpu, inst) => ccf(cpu, inst);

  functions[0x40] = fn (cpu, inst) => reg2Reg(cpu, inst, B, B);
  functions[0x41] = fn (cpu, inst) => reg2Reg(cpu, inst, B, C);
  functions[0x42] = fn (cpu, inst) => reg2Reg(cpu, inst, B, D);
  functions[0x43] = fn (cpu, inst) => reg2Reg(cpu, inst, B, E);
  functions[0x44] = fn (cpu, inst) => reg2Reg(cpu, inst, B, H);
  functions[0x45] = fn (cpu, inst) => reg2Reg(cpu, inst, B, L);
  functions[0x46] = fn (cpu, inst) => reg2Reg(cpu, inst, B, I_HL);
  functions[0x47] = fn (cpu, inst) => reg2Reg(cpu, inst, B, A);
  functions[0x48] = fn (cpu, inst) => reg2Reg(cpu, inst, C, B);
  functions[0x49] = fn (cpu, inst) => reg2Reg(cpu, inst, C, C);
  functions[0x4a] = fn (cpu, inst) => reg2Reg(cpu, inst, C, D);
  functions[0x4b] = fn (cpu, inst) => reg2Reg(cpu, inst, C, E);
  functions[0x4c] = fn (cpu, inst) => reg2Reg(cpu, inst, C, H);
  functions[0x4d] = fn (cpu, inst) => reg2Reg(cpu, inst, C, L);
  functions[0x4e] = fn (cpu, inst) => reg2Reg(cpu, inst, C, I_HL);
  functions[0x4f] = fn (cpu, inst) => reg2Reg(cpu, inst, C, A);

  functions[0x50] = fn (cpu, inst) => reg2Reg(cpu, inst, D, B);
  functions[0x51] = fn (cpu, inst) => reg2Reg(cpu, inst, D, C);
  functions[0x52] = fn (cpu, inst) => reg2Reg(cpu, inst, D, D);
  functions[0x53] = fn (cpu, inst) => reg2Reg(cpu, inst, D, E);
  functions[0x54] = fn (cpu, inst) => reg2Reg(cpu, inst, D, H);
  functions[0x55] = fn (cpu, inst) => reg2Reg(cpu, inst, D, L);
  functions[0x56] = fn (cpu, inst) => reg2Reg(cpu, inst, D, I_HL);
  functions[0x57] = fn (cpu, inst) => reg2Reg(cpu, inst, D, A);
  functions[0x58] = fn (cpu, inst) => reg2Reg(cpu, inst, E, B);
  functions[0x59] = fn (cpu, inst) => reg2Reg(cpu, inst, E, C);
  functions[0x5a] = fn (cpu, inst) => reg2Reg(cpu, inst, E, D);
  functions[0x5b] = fn (cpu, inst) => reg2Reg(cpu, inst, E, E);
  functions[0x5c] = fn (cpu, inst) => reg2Reg(cpu, inst, E, H);
  functions[0x5d] = fn (cpu, inst) => reg2Reg(cpu, inst, E, L);
  functions[0x5e] = fn (cpu, inst) => reg2Reg(cpu, inst, E, I_HL);
  functions[0x5f] = fn (cpu, inst) => reg2Reg(cpu, inst, E, A);

  functions[0x60] = fn (cpu, inst) => reg2Reg(cpu, inst, H, B);
  functions[0x61] = fn (cpu, inst) => reg2Reg(cpu, inst, H, C);
  functions[0x62] = fn (cpu, inst) => reg2Reg(cpu, inst, H, D);
  functions[0x63] = fn (cpu, inst) => reg2Reg(cpu, inst, H, E);
  functions[0x64] = fn (cpu, inst) => reg2Reg(cpu, inst, H, H);
  functions[0x65] = fn (cpu, inst) => reg2Reg(cpu, inst, H, L);
  functions[0x66] = fn (cpu, inst) => reg2Reg(cpu, inst, H, I_HL);
  functions[0x67] = fn (cpu, inst) => reg2Reg(cpu, inst, H, A);
  functions[0x68] = fn (cpu, inst) => reg2Reg(cpu, inst, L, B);
  functions[0x69] = fn (cpu, inst) => reg2Reg(cpu, inst, L, C);
  functions[0x6a] = fn (cpu, inst) => reg2Reg(cpu, inst, L, D);
  functions[0x6b] = fn (cpu, inst) => reg2Reg(cpu, inst, L, E);
  functions[0x6c] = fn (cpu, inst) => reg2Reg(cpu, inst, L, H);
  functions[0x6d] = fn (cpu, inst) => reg2Reg(cpu, inst, L, L);
  functions[0x6e] = fn (cpu, inst) => reg2Reg(cpu, inst, L, I_HL);
  functions[0x6f] = fn (cpu, inst) => reg2Reg(cpu, inst, L, A);

  functions[0x70] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, B);
  functions[0x71] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, C);
  functions[0x72] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, D);
  functions[0x73] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, E);
  functions[0x74] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, H);
  functions[0x75] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, L);
  functions[0x76] = fn (cpu, inst) => halt(cpu, inst);
  functions[0x77] = fn (cpu, inst) => reg2Reg(cpu, inst, I_HL, A);
  functions[0x78] = fn (cpu, inst) => reg2Reg(cpu, inst, A, B);
  functions[0x79] = fn (cpu, inst) => reg2Reg(cpu, inst, A, C);
  functions[0x7a] = fn (cpu, inst) => reg2Reg(cpu, inst, A, D);
  functions[0x7b] = fn (cpu, inst) => reg2Reg(cpu, inst, A, E);
  functions[0x7c] = fn (cpu, inst) => reg2Reg(cpu, inst, A, H);
  functions[0x7d] = fn (cpu, inst) => reg2Reg(cpu, inst, A, L);
  functions[0x7e] = fn (cpu, inst) => reg2Reg(cpu, inst, A, I_HL);
  functions[0x7f] = fn (cpu, inst) => reg2Reg(cpu, inst, A, A);

  functions[0x80] = fn (cpu, inst) => addRegReg(cpu, inst, A, B);
  functions[0x81] = fn (cpu, inst) => addRegReg(cpu, inst, A, C);
  functions[0x82] = fn (cpu, inst) => addRegReg(cpu, inst, A, D);
  functions[0x83] = fn (cpu, inst) => addRegReg(cpu, inst, A, E);
  functions[0x84] = fn (cpu, inst) => addRegReg(cpu, inst, A, H);
  functions[0x85] = fn (cpu, inst) => addRegReg(cpu, inst, A, L);
  functions[0x86] = fn (cpu, inst) => addRegReg(cpu, inst, A, I_HL);
  functions[0x87] = fn (cpu, inst) => addRegReg(cpu, inst, A, A);
  functions[0x88] = fn (cpu, inst) => adcRegReg(cpu, inst, A, B);
  functions[0x89] = fn (cpu, inst) => adcRegReg(cpu, inst, A, C);
  functions[0x8a] = fn (cpu, inst) => adcRegReg(cpu, inst, A, D);
  functions[0x8b] = fn (cpu, inst) => adcRegReg(cpu, inst, A, E);
  functions[0x8c] = fn (cpu, inst) => adcRegReg(cpu, inst, A, H);
  functions[0x8d] = fn (cpu, inst) => adcRegReg(cpu, inst, A, L);
  functions[0x8e] = fn (cpu, inst) => adcRegReg(cpu, inst, A, I_HL);
  functions[0x8f] = fn (cpu, inst) => adcRegReg(cpu, inst, A, A);

  functions[0x90] = fn (cpu, inst) => subRegReg(cpu, inst, A, B);
  functions[0x91] = fn (cpu, inst) => subRegReg(cpu, inst, A, C);
  functions[0x92] = fn (cpu, inst) => subRegReg(cpu, inst, A, D);
  functions[0x93] = fn (cpu, inst) => subRegReg(cpu, inst, A, E);
  functions[0x94] = fn (cpu, inst) => subRegReg(cpu, inst, A, H);
  functions[0x95] = fn (cpu, inst) => subRegReg(cpu, inst, A, L);
  functions[0x96] = fn (cpu, inst) => subRegReg(cpu, inst, A, I_HL);
  functions[0x97] = fn (cpu, inst) => subRegReg(cpu, inst, A, A);
  functions[0x98] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, B);
  functions[0x99] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, C);
  functions[0x9a] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, D);
  functions[0x9b] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, E);
  functions[0x9c] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, H);
  functions[0x9d] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, L);
  functions[0x9e] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, I_HL);
  functions[0x9f] = fn (cpu, inst) => sbcRegReg(cpu, inst, A, A);

  functions[0xa0] = fn (cpu, inst) => andRegReg(cpu, inst, A, B);
  functions[0xa1] = fn (cpu, inst) => andRegReg(cpu, inst, A, C);
  functions[0xa2] = fn (cpu, inst) => andRegReg(cpu, inst, A, D);
  functions[0xa3] = fn (cpu, inst) => andRegReg(cpu, inst, A, E);
  functions[0xa4] = fn (cpu, inst) => andRegReg(cpu, inst, A, H);
  functions[0xa5] = fn (cpu, inst) => andRegReg(cpu, inst, A, L);
  functions[0xa6] = fn (cpu, inst) => andRegReg(cpu, inst, A, I_HL);
  functions[0xa7] = fn (cpu, inst) => andRegReg(cpu, inst, A, A);
  functions[0xa8] = fn (cpu, inst) => xorReg(cpu, inst, A, B);
  functions[0xa9] = fn (cpu, inst) => xorReg(cpu, inst, A, C);
  functions[0xaa] = fn (cpu, inst) => xorReg(cpu, inst, A, D);
  functions[0xab] = fn (cpu, inst) => xorReg(cpu, inst, A, E);
  functions[0xac] = fn (cpu, inst) => xorReg(cpu, inst, A, H);
  functions[0xad] = fn (cpu, inst) => xorReg(cpu, inst, A, L);
  functions[0xae] = fn (cpu, inst) => xorReg(cpu, inst, A, I_HL);
  functions[0xaf] = fn (cpu, inst) => xorReg(cpu, inst, A, A);

  functions[0xb0] = fn (cpu, inst) => orRegReg(cpu, inst, A, B);
  functions[0xb1] = fn (cpu, inst) => orRegReg(cpu, inst, A, C);
  functions[0xb2] = fn (cpu, inst) => orRegReg(cpu, inst, A, D);
  functions[0xb3] = fn (cpu, inst) => orRegReg(cpu, inst, A, E);
  functions[0xb4] = fn (cpu, inst) => orRegReg(cpu, inst, A, H);
  functions[0xb5] = fn (cpu, inst) => orRegReg(cpu, inst, A, L);
  functions[0xb6] = fn (cpu, inst) => orRegReg(cpu, inst, A, I_HL);
  functions[0xb7] = fn (cpu, inst) => orRegReg(cpu, inst, A, A);
  functions[0xb8] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, B);
  functions[0xb9] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, C);
  functions[0xba] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, D);
  functions[0xbb] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, E);
  functions[0xbc] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, H);
  functions[0xbd] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, L);
  functions[0xbe] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, I_HL);
  functions[0xbf] = fn (cpu, inst) => cmpRegReg(cpu, inst, A, A);

  functions[0xc0] = fn (cpu, inst) => ret(cpu, inst, NZ);
  functions[0xc1] = fn (cpu, inst) => popReg16(cpu, inst, BC);
  functions[0xc2] = fn (cpu, inst) => jumpImm(cpu, inst, NZ);
  functions[0xc3] = fn (cpu, inst) => jumpImm(cpu, inst, NONE);
  functions[0xc4] = fn (cpu, inst) => callImm(cpu, inst, NZ);
  functions[0xc5] = fn (cpu, inst) => pushReg16(cpu, inst, BC);
  functions[0xc6] = fn (cpu, inst) => addRegImm8(cpu, inst, A);
  functions[0xc7] = fn (cpu, inst) => rst(cpu, inst, 0x00);
  functions[0xc8] = fn (cpu, inst) => ret(cpu, inst, Z);
  functions[0xc9] = fn (cpu, inst) => ret(cpu, inst, NONE);
  functions[0xca] = fn (cpu, inst) => jumpImm(cpu, inst, Z);
  functions[0xcc] = fn (cpu, inst) => callImm(cpu, inst, Z);
  functions[0xcd] = fn (cpu, inst) => callImm(cpu, inst, NONE);
  functions[0xce] = fn (cpu, inst) => adcRegImm8(cpu, inst, A);
  functions[0xcf] = fn (cpu, inst) => rst(cpu, inst, 0x08);

  functions[0xd0] = fn (cpu, inst) => ret(cpu, inst, NC);
  functions[0xd1] = fn (cpu, inst) => popReg16(cpu, inst, DE);
  functions[0xd2] = fn (cpu, inst) => jumpImm(cpu, inst, NC);
  functions[0xd4] = fn (cpu, inst) => callImm(cpu, inst, NC);
  functions[0xd5] = fn (cpu, inst) => pushReg16(cpu, inst, DE);
  functions[0xd6] = fn (cpu, inst) => subRegImm8(cpu, inst, A);
  functions[0xd7] = fn (cpu, inst) => rst(cpu, inst, 0x10);
  functions[0xd8] = fn (cpu, inst) => ret(cpu, inst, C);
  functions[0xd9] = fn (cpu, inst) => reti(cpu, inst);
  functions[0xda] = fn (cpu, inst) => jumpImm(cpu, inst, C);
  functions[0xdc] = fn (cpu, inst) => callImm(cpu, inst, C);
  functions[0xde] = fn (cpu, inst) => sbcRegImm8(cpu, inst, A);
  functions[0xdf] = fn (cpu, inst) => rst(cpu, inst, 0x18);

  functions[0xe0] = fn (cpu, inst) => reg2MemImm8(cpu, inst, A, 0xFF00);
  functions[0xe1] = fn (cpu, inst) => popReg16(cpu, inst, HL);
  functions[0xe2] = fn (cpu, inst) => reg2MemReg(cpu, inst, A, C, 0xFF00);
  functions[0xe5] = fn (cpu, inst) => pushReg16(cpu, inst, HL);
  functions[0xe6] = fn (cpu, inst) => andRegImm(cpu, inst, A);
  functions[0xe7] = fn (cpu, inst) => rst(cpu, inst, 0x20);
  functions[0xe8] = fn (cpu, inst) => addReg16Imm8(cpu, inst, SP);
  functions[0xe9] = fn (cpu, inst) => jumpReg(cpu, inst, HL);
  functions[0xea] = fn (cpu, inst) => reg2MemImm(cpu, inst, A);
  functions[0xee] = fn (cpu, inst) => xorRegImm8(cpu, inst, A);
  functions[0xef] = fn (cpu, inst) => rst(cpu, inst, 0x28);

  functions[0xf0] = fn (cpu, inst) => memImm82Reg(cpu, inst, A, 0xFF00);
  functions[0xf1] = fn (cpu, inst) => popReg16(cpu, inst, AF);
  functions[0xf2] = fn (cpu, inst) => memRegOff2Reg(cpu, inst, A, C, 0xFF00);
  functions[0xf3] = fn (cpu, inst) => setInterrupts(cpu, inst, false);  
  functions[0xf5] = fn (cpu, inst) => pushReg16(cpu, inst, AF);
  functions[0xf6] = fn (cpu, inst) => orRegImm8(cpu, inst, A);
  functions[0xf7] = fn (cpu, inst) => rst(cpu, inst, 0x30);
  functions[0xf8] = fn (cpu, inst) => reg162Reg16addImm8(cpu, inst, HL, SP);
  functions[0xf9] = fn (cpu, inst) => reg162Reg16(cpu, inst, SP, HL);
  functions[0xfa] = fn (cpu, inst) => memImm2Reg(cpu, inst, A);
  functions[0xfb] = fn (cpu, inst) => setInterrupts(cpu, inst, true);
  functions[0xfe] = fn (cpu, inst) => cmpRegImm(cpu, inst, A);
  functions[0xff] = fn (cpu, inst) => rst(cpu, inst, 0x38);

  /* CB Insts */
  functions_CB[0x00] = fn (cpu, inst) => rotateLeft(cpu, inst, B);
  functions_CB[0x01] = fn (cpu, inst) => rotateLeft(cpu, inst, C);
  functions_CB[0x02] = fn (cpu, inst) => rotateLeft(cpu, inst, D);
  functions_CB[0x03] = fn (cpu, inst) => rotateLeft(cpu, inst, E);
  functions_CB[0x04] = fn (cpu, inst) => rotateLeft(cpu, inst, H);
  functions_CB[0x05] = fn (cpu, inst) => rotateLeft(cpu, inst, L);
  functions_CB[0x06] = fn (cpu, inst) => rotateLeft(cpu, inst, I_HL);
  functions_CB[0x07] = fn (cpu, inst) => rotateLeft(cpu, inst, A);
  functions_CB[0x08] = fn (cpu, inst) => rotateRight(cpu, inst, B);
  functions_CB[0x09] = fn (cpu, inst) => rotateRight(cpu, inst, C);
  functions_CB[0x0a] = fn (cpu, inst) => rotateRight(cpu, inst, D);
  functions_CB[0x0b] = fn (cpu, inst) => rotateRight(cpu, inst, E);
  functions_CB[0x0c] = fn (cpu, inst) => rotateRight(cpu, inst, H);
  functions_CB[0x0d] = fn (cpu, inst) => rotateRight(cpu, inst, L);
  functions_CB[0x0e] = fn (cpu, inst) => rotateRight(cpu, inst, I_HL);
  functions_CB[0x0f] = fn (cpu, inst) => rotateRight(cpu, inst, A);

  functions_CB[0x10] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, B);
  functions_CB[0x11] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, C);
  functions_CB[0x12] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, D);
  functions_CB[0x13] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, E);
  functions_CB[0x14] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, H);
  functions_CB[0x15] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, L);
  functions_CB[0x16] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, I_HL);
  functions_CB[0x17] = fn (cpu, inst) => rotateLeftWithCarry(cpu, inst, A);
  functions_CB[0x18] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, B);
  functions_CB[0x19] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, C);
  functions_CB[0x1a] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, D);
  functions_CB[0x1b] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, E);
  functions_CB[0x1c] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, H);
  functions_CB[0x1d] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, L);
  functions_CB[0x1e] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, I_HL);
  functions_CB[0x1f] = fn (cpu, inst) => rotateRightWithCarry(cpu, inst, A);

  functions_CB[0x20] = fn (cpu, inst) => slaReg(cpu, inst, B);
  functions_CB[0x21] = fn (cpu, inst) => slaReg(cpu, inst, C);
  functions_CB[0x22] = fn (cpu, inst) => slaReg(cpu, inst, D);
  functions_CB[0x23] = fn (cpu, inst) => slaReg(cpu, inst, E);
  functions_CB[0x24] = fn (cpu, inst) => slaReg(cpu, inst, H);
  functions_CB[0x25] = fn (cpu, inst) => slaReg(cpu, inst, L);
  functions_CB[0x26] = fn (cpu, inst) => slaReg(cpu, inst, I_HL);
  functions_CB[0x27] = fn (cpu, inst) => slaReg(cpu, inst, A);
  functions_CB[0x28] = fn (cpu, inst) => sraReg(cpu, inst, B);
  functions_CB[0x29] = fn (cpu, inst) => sraReg(cpu, inst, C);
  functions_CB[0x2a] = fn (cpu, inst) => sraReg(cpu, inst, D);
  functions_CB[0x2b] = fn (cpu, inst) => sraReg(cpu, inst, E);
  functions_CB[0x2c] = fn (cpu, inst) => sraReg(cpu, inst, H);
  functions_CB[0x2d] = fn (cpu, inst) => sraReg(cpu, inst, L);
  functions_CB[0x2e] = fn (cpu, inst) => sraReg(cpu, inst, I_HL);
  functions_CB[0x2f] = fn (cpu, inst) => sraReg(cpu, inst, A);

  functions_CB[0x30] = fn (cpu, inst) => swapReg(cpu, inst, B);
  functions_CB[0x31] = fn (cpu, inst) => swapReg(cpu, inst, C);
  functions_CB[0x32] = fn (cpu, inst) => swapReg(cpu, inst, D);
  functions_CB[0x33] = fn (cpu, inst) => swapReg(cpu, inst, E);
  functions_CB[0x34] = fn (cpu, inst) => swapReg(cpu, inst, H);
  functions_CB[0x35] = fn (cpu, inst) => swapReg(cpu, inst, L);
  functions_CB[0x36] = fn (cpu, inst) => swapReg(cpu, inst, I_HL);
  functions_CB[0x37] = fn (cpu, inst) => swapReg(cpu, inst, A);
  functions_CB[0x38] = fn (cpu, inst) => srlReg(cpu, inst, B);
  functions_CB[0x39] = fn (cpu, inst) => srlReg(cpu, inst, C);
  functions_CB[0x3a] = fn (cpu, inst) => srlReg(cpu, inst, D);
  functions_CB[0x3b] = fn (cpu, inst) => srlReg(cpu, inst, E);
  functions_CB[0x3c] = fn (cpu, inst) => srlReg(cpu, inst, H);
  functions_CB[0x3d] = fn (cpu, inst) => srlReg(cpu, inst, L);
  functions_CB[0x3e] = fn (cpu, inst) => srlReg(cpu, inst, I_HL);
  functions_CB[0x3f] = fn (cpu, inst) => srlReg(cpu, inst, A);

  functions_CB[0x40] = fn (cpu, inst) => bitReg(cpu, inst, B, 0);
  functions_CB[0x41] = fn (cpu, inst) => bitReg(cpu, inst, C, 0);
  functions_CB[0x42] = fn (cpu, inst) => bitReg(cpu, inst, D, 0);
  functions_CB[0x43] = fn (cpu, inst) => bitReg(cpu, inst, E, 0);
  functions_CB[0x44] = fn (cpu, inst) => bitReg(cpu, inst, H, 0);
  functions_CB[0x45] = fn (cpu, inst) => bitReg(cpu, inst, L, 0);
  functions_CB[0x46] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 0);
  functions_CB[0x47] = fn (cpu, inst) => bitReg(cpu, inst, A, 0);
  functions_CB[0x48] = fn (cpu, inst) => bitReg(cpu, inst, B, 1);
  functions_CB[0x49] = fn (cpu, inst) => bitReg(cpu, inst, C, 1);
  functions_CB[0x4a] = fn (cpu, inst) => bitReg(cpu, inst, D, 1);
  functions_CB[0x4b] = fn (cpu, inst) => bitReg(cpu, inst, E, 1);
  functions_CB[0x4c] = fn (cpu, inst) => bitReg(cpu, inst, H, 1);
  functions_CB[0x4d] = fn (cpu, inst) => bitReg(cpu, inst, L, 1);
  functions_CB[0x4e] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 1);
  functions_CB[0x4f] = fn (cpu, inst) => bitReg(cpu, inst, A, 1);

  functions_CB[0x50] = fn (cpu, inst) => bitReg(cpu, inst, B, 2);
  functions_CB[0x51] = fn (cpu, inst) => bitReg(cpu, inst, C, 2);
  functions_CB[0x52] = fn (cpu, inst) => bitReg(cpu, inst, D, 2);
  functions_CB[0x53] = fn (cpu, inst) => bitReg(cpu, inst, E, 2);
  functions_CB[0x54] = fn (cpu, inst) => bitReg(cpu, inst, H, 2);
  functions_CB[0x55] = fn (cpu, inst) => bitReg(cpu, inst, L, 2);
  functions_CB[0x56] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 2);
  functions_CB[0x57] = fn (cpu, inst) => bitReg(cpu, inst, A, 2);
  functions_CB[0x58] = fn (cpu, inst) => bitReg(cpu, inst, B, 3);
  functions_CB[0x59] = fn (cpu, inst) => bitReg(cpu, inst, C, 3);
  functions_CB[0x5a] = fn (cpu, inst) => bitReg(cpu, inst, D, 3);
  functions_CB[0x5b] = fn (cpu, inst) => bitReg(cpu, inst, E, 3);
  functions_CB[0x5c] = fn (cpu, inst) => bitReg(cpu, inst, H, 3);
  functions_CB[0x5d] = fn (cpu, inst) => bitReg(cpu, inst, L, 3);
  functions_CB[0x5e] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 3);
  functions_CB[0x5f] = fn (cpu, inst) => bitReg(cpu, inst, A, 3);

  functions_CB[0x60] = fn (cpu, inst) => bitReg(cpu, inst, B, 4);
  functions_CB[0x61] = fn (cpu, inst) => bitReg(cpu, inst, C, 4);
  functions_CB[0x62] = fn (cpu, inst) => bitReg(cpu, inst, D, 4);
  functions_CB[0x63] = fn (cpu, inst) => bitReg(cpu, inst, E, 4);
  functions_CB[0x64] = fn (cpu, inst) => bitReg(cpu, inst, H, 4);
  functions_CB[0x65] = fn (cpu, inst) => bitReg(cpu, inst, L, 4);
  functions_CB[0x66] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 4);
  functions_CB[0x67] = fn (cpu, inst) => bitReg(cpu, inst, A, 4);
  functions_CB[0x68] = fn (cpu, inst) => bitReg(cpu, inst, B, 5);
  functions_CB[0x69] = fn (cpu, inst) => bitReg(cpu, inst, C, 5);
  functions_CB[0x6a] = fn (cpu, inst) => bitReg(cpu, inst, D, 5);
  functions_CB[0x6b] = fn (cpu, inst) => bitReg(cpu, inst, E, 5);
  functions_CB[0x6c] = fn (cpu, inst) => bitReg(cpu, inst, H, 5);
  functions_CB[0x6d] = fn (cpu, inst) => bitReg(cpu, inst, L, 5);
  functions_CB[0x6e] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 5);
  functions_CB[0x6f] = fn (cpu, inst) => bitReg(cpu, inst, A, 5);

  functions_CB[0x70] = fn (cpu, inst) => bitReg(cpu, inst, B, 6);
  functions_CB[0x71] = fn (cpu, inst) => bitReg(cpu, inst, C, 6);
  functions_CB[0x72] = fn (cpu, inst) => bitReg(cpu, inst, D, 6);
  functions_CB[0x73] = fn (cpu, inst) => bitReg(cpu, inst, E, 6);
  functions_CB[0x74] = fn (cpu, inst) => bitReg(cpu, inst, H, 6);
  functions_CB[0x75] = fn (cpu, inst) => bitReg(cpu, inst, L, 6);
  functions_CB[0x76] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 6);
  functions_CB[0x77] = fn (cpu, inst) => bitReg(cpu, inst, A, 6);
  functions_CB[0x78] = fn (cpu, inst) => bitReg(cpu, inst, B, 7);
  functions_CB[0x79] = fn (cpu, inst) => bitReg(cpu, inst, C, 7);
  functions_CB[0x7a] = fn (cpu, inst) => bitReg(cpu, inst, D, 7);
  functions_CB[0x7b] = fn (cpu, inst) => bitReg(cpu, inst, E, 7);
  functions_CB[0x7c] = fn (cpu, inst) => bitReg(cpu, inst, H, 7);
  functions_CB[0x7d] = fn (cpu, inst) => bitReg(cpu, inst, L, 7);
  functions_CB[0x7e] = fn (cpu, inst) => bitReg(cpu, inst, I_HL, 7);
  functions_CB[0x7f] = fn (cpu, inst) => bitReg(cpu, inst, A, 7);

  functions_CB[0x80] = fn (cpu, inst) => resBitReg(cpu, inst, B, 0);
  functions_CB[0x81] = fn (cpu, inst) => resBitReg(cpu, inst, C, 0);
  functions_CB[0x82] = fn (cpu, inst) => resBitReg(cpu, inst, D, 0);
  functions_CB[0x83] = fn (cpu, inst) => resBitReg(cpu, inst, E, 0);
  functions_CB[0x84] = fn (cpu, inst) => resBitReg(cpu, inst, H, 0);
  functions_CB[0x85] = fn (cpu, inst) => resBitReg(cpu, inst, L, 0);
  functions_CB[0x86] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 0);
  functions_CB[0x87] = fn (cpu, inst) => resBitReg(cpu, inst, A, 0);
  functions_CB[0x88] = fn (cpu, inst) => resBitReg(cpu, inst, B, 1);
  functions_CB[0x89] = fn (cpu, inst) => resBitReg(cpu, inst, C, 1);
  functions_CB[0x8a] = fn (cpu, inst) => resBitReg(cpu, inst, D, 1);
  functions_CB[0x8b] = fn (cpu, inst) => resBitReg(cpu, inst, E, 1);
  functions_CB[0x8c] = fn (cpu, inst) => resBitReg(cpu, inst, H, 1);
  functions_CB[0x8d] = fn (cpu, inst) => resBitReg(cpu, inst, L, 1);
  functions_CB[0x8e] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 1);
  functions_CB[0x8f] = fn (cpu, inst) => resBitReg(cpu, inst, A, 1);

  functions_CB[0x90] = fn (cpu, inst) => resBitReg(cpu, inst, B, 2);
  functions_CB[0x91] = fn (cpu, inst) => resBitReg(cpu, inst, C, 2);
  functions_CB[0x92] = fn (cpu, inst) => resBitReg(cpu, inst, D, 2);
  functions_CB[0x93] = fn (cpu, inst) => resBitReg(cpu, inst, E, 2);
  functions_CB[0x94] = fn (cpu, inst) => resBitReg(cpu, inst, H, 2);
  functions_CB[0x95] = fn (cpu, inst) => resBitReg(cpu, inst, L, 2);
  functions_CB[0x96] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 2);
  functions_CB[0x97] = fn (cpu, inst) => resBitReg(cpu, inst, A, 2);
  functions_CB[0x98] = fn (cpu, inst) => resBitReg(cpu, inst, B, 3);
  functions_CB[0x99] = fn (cpu, inst) => resBitReg(cpu, inst, C, 3);
  functions_CB[0x9a] = fn (cpu, inst) => resBitReg(cpu, inst, D, 3);
  functions_CB[0x9b] = fn (cpu, inst) => resBitReg(cpu, inst, E, 3);
  functions_CB[0x9c] = fn (cpu, inst) => resBitReg(cpu, inst, H, 3);
  functions_CB[0x9d] = fn (cpu, inst) => resBitReg(cpu, inst, L, 3);
  functions_CB[0x9e] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 3);
  functions_CB[0x9f] = fn (cpu, inst) => resBitReg(cpu, inst, A, 3);

  functions_CB[0xa0] = fn (cpu, inst) => resBitReg(cpu, inst, B, 4);
  functions_CB[0xa1] = fn (cpu, inst) => resBitReg(cpu, inst, C, 4);
  functions_CB[0xa2] = fn (cpu, inst) => resBitReg(cpu, inst, D, 4);
  functions_CB[0xa3] = fn (cpu, inst) => resBitReg(cpu, inst, E, 4);
  functions_CB[0xa4] = fn (cpu, inst) => resBitReg(cpu, inst, H, 4);
  functions_CB[0xa5] = fn (cpu, inst) => resBitReg(cpu, inst, L, 4);
  functions_CB[0xa6] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 4);
  functions_CB[0xa7] = fn (cpu, inst) => resBitReg(cpu, inst, A, 4);
  functions_CB[0xa8] = fn (cpu, inst) => resBitReg(cpu, inst, B, 5);
  functions_CB[0xa9] = fn (cpu, inst) => resBitReg(cpu, inst, C, 5);
  functions_CB[0xaa] = fn (cpu, inst) => resBitReg(cpu, inst, D, 5);
  functions_CB[0xab] = fn (cpu, inst) => resBitReg(cpu, inst, E, 5);
  functions_CB[0xac] = fn (cpu, inst) => resBitReg(cpu, inst, H, 5);
  functions_CB[0xad] = fn (cpu, inst) => resBitReg(cpu, inst, L, 5);
  functions_CB[0xae] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 5);
  functions_CB[0xaf] = fn (cpu, inst) => resBitReg(cpu, inst, A, 5);

  functions_CB[0xb0] = fn (cpu, inst) => resBitReg(cpu, inst, B, 6);
  functions_CB[0xb1] = fn (cpu, inst) => resBitReg(cpu, inst, C, 6);
  functions_CB[0xb2] = fn (cpu, inst) => resBitReg(cpu, inst, D, 6);
  functions_CB[0xb3] = fn (cpu, inst) => resBitReg(cpu, inst, E, 6);
  functions_CB[0xb4] = fn (cpu, inst) => resBitReg(cpu, inst, H, 6);
  functions_CB[0xb5] = fn (cpu, inst) => resBitReg(cpu, inst, L, 6);
  functions_CB[0xb6] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 6);
  functions_CB[0xb7] = fn (cpu, inst) => resBitReg(cpu, inst, A, 6);
  functions_CB[0xb8] = fn (cpu, inst) => resBitReg(cpu, inst, B, 7);
  functions_CB[0xb9] = fn (cpu, inst) => resBitReg(cpu, inst, C, 7);
  functions_CB[0xba] = fn (cpu, inst) => resBitReg(cpu, inst, D, 7);
  functions_CB[0xbb] = fn (cpu, inst) => resBitReg(cpu, inst, E, 7);
  functions_CB[0xbc] = fn (cpu, inst) => resBitReg(cpu, inst, H, 7);
  functions_CB[0xbd] = fn (cpu, inst) => resBitReg(cpu, inst, L, 7);
  functions_CB[0xbe] = fn (cpu, inst) => resBitReg(cpu, inst, I_HL, 7);
  functions_CB[0xbf] = fn (cpu, inst) => resBitReg(cpu, inst, A, 7);

  functions_CB[0xc0] = fn (cpu, inst) => setBitReg(cpu, inst, B, 0);
  functions_CB[0xc1] = fn (cpu, inst) => setBitReg(cpu, inst, C, 0);
  functions_CB[0xc2] = fn (cpu, inst) => setBitReg(cpu, inst, D, 0);
  functions_CB[0xc3] = fn (cpu, inst) => setBitReg(cpu, inst, E, 0);
  functions_CB[0xc4] = fn (cpu, inst) => setBitReg(cpu, inst, H, 0);
  functions_CB[0xc5] = fn (cpu, inst) => setBitReg(cpu, inst, L, 0);
  functions_CB[0xc6] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 0);
  functions_CB[0xc7] = fn (cpu, inst) => setBitReg(cpu, inst, A, 0);
  functions_CB[0xc8] = fn (cpu, inst) => setBitReg(cpu, inst, B, 1);
  functions_CB[0xc9] = fn (cpu, inst) => setBitReg(cpu, inst, C, 1);
  functions_CB[0xca] = fn (cpu, inst) => setBitReg(cpu, inst, D, 1);
  functions_CB[0xcb] = fn (cpu, inst) => setBitReg(cpu, inst, E, 1);
  functions_CB[0xcc] = fn (cpu, inst) => setBitReg(cpu, inst, H, 1);
  functions_CB[0xcd] = fn (cpu, inst) => setBitReg(cpu, inst, L, 1);
  functions_CB[0xce] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 1);
  functions_CB[0xcf] = fn (cpu, inst) => setBitReg(cpu, inst, A, 1);

  functions_CB[0xd0] = fn (cpu, inst) => setBitReg(cpu, inst, B, 2);
  functions_CB[0xd1] = fn (cpu, inst) => setBitReg(cpu, inst, C, 2);
  functions_CB[0xd2] = fn (cpu, inst) => setBitReg(cpu, inst, D, 2);
  functions_CB[0xd3] = fn (cpu, inst) => setBitReg(cpu, inst, E, 2);
  functions_CB[0xd4] = fn (cpu, inst) => setBitReg(cpu, inst, H, 2);
  functions_CB[0xd5] = fn (cpu, inst) => setBitReg(cpu, inst, L, 2);
  functions_CB[0xd6] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 2);
  functions_CB[0xd7] = fn (cpu, inst) => setBitReg(cpu, inst, A, 2);
  functions_CB[0xd8] = fn (cpu, inst) => setBitReg(cpu, inst, B, 3);
  functions_CB[0xd9] = fn (cpu, inst) => setBitReg(cpu, inst, C, 3);
  functions_CB[0xda] = fn (cpu, inst) => setBitReg(cpu, inst, D, 3);
  functions_CB[0xdb] = fn (cpu, inst) => setBitReg(cpu, inst, E, 3);
  functions_CB[0xdc] = fn (cpu, inst) => setBitReg(cpu, inst, H, 3);
  functions_CB[0xdd] = fn (cpu, inst) => setBitReg(cpu, inst, L, 3);
  functions_CB[0xde] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 3);
  functions_CB[0xdf] = fn (cpu, inst) => setBitReg(cpu, inst, A, 3);

  functions_CB[0xe0] = fn (cpu, inst) => setBitReg(cpu, inst, B, 4);
  functions_CB[0xe1] = fn (cpu, inst) => setBitReg(cpu, inst, C, 4);
  functions_CB[0xe2] = fn (cpu, inst) => setBitReg(cpu, inst, D, 4);
  functions_CB[0xe3] = fn (cpu, inst) => setBitReg(cpu, inst, E, 4);
  functions_CB[0xe4] = fn (cpu, inst) => setBitReg(cpu, inst, H, 4);
  functions_CB[0xe5] = fn (cpu, inst) => setBitReg(cpu, inst, L, 4);
  functions_CB[0xe6] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 4);
  functions_CB[0xe7] = fn (cpu, inst) => setBitReg(cpu, inst, A, 4);
  functions_CB[0xe8] = fn (cpu, inst) => setBitReg(cpu, inst, B, 5);
  functions_CB[0xe9] = fn (cpu, inst) => setBitReg(cpu, inst, C, 5);
  functions_CB[0xea] = fn (cpu, inst) => setBitReg(cpu, inst, D, 5);
  functions_CB[0xeb] = fn (cpu, inst) => setBitReg(cpu, inst, E, 5);
  functions_CB[0xec] = fn (cpu, inst) => setBitReg(cpu, inst, H, 5);
  functions_CB[0xed] = fn (cpu, inst) => setBitReg(cpu, inst, L, 5);
  functions_CB[0xee] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 5);
  functions_CB[0xef] = fn (cpu, inst) => setBitReg(cpu, inst, A, 5);

  functions_CB[0xf0] = fn (cpu, inst) => setBitReg(cpu, inst, B, 6);
  functions_CB[0xf1] = fn (cpu, inst) => setBitReg(cpu, inst, C, 6);
  functions_CB[0xf2] = fn (cpu, inst) => setBitReg(cpu, inst, D, 6);
  functions_CB[0xf3] = fn (cpu, inst) => setBitReg(cpu, inst, E, 6);
  functions_CB[0xf4] = fn (cpu, inst) => setBitReg(cpu, inst, H, 6);
  functions_CB[0xf5] = fn (cpu, inst) => setBitReg(cpu, inst, L, 6);
  functions_CB[0xf6] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 6);
  functions_CB[0xf7] = fn (cpu, inst) => setBitReg(cpu, inst, A, 6);
  functions_CB[0xf8] = fn (cpu, inst) => setBitReg(cpu, inst, B, 7);
  functions_CB[0xf9] = fn (cpu, inst) => setBitReg(cpu, inst, C, 7);
  functions_CB[0xfa] = fn (cpu, inst) => setBitReg(cpu, inst, D, 7);
  functions_CB[0xfb] = fn (cpu, inst) => setBitReg(cpu, inst, E, 7);
  functions_CB[0xfc] = fn (cpu, inst) => setBitReg(cpu, inst, H, 7);
  functions_CB[0xfd] = fn (cpu, inst) => setBitReg(cpu, inst, L, 7);
  functions_CB[0xfe] = fn (cpu, inst) => setBitReg(cpu, inst, I_HL, 7);
  functions_CB[0xff] = fn (cpu, inst) => setBitReg(cpu, inst, A, 7);
}


/*
     Tables for easy deconding
*/

UInt8[256] latencies = {
     /*  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F */
/* 0 */  4,12, 8, 8, 4, 4, 8, 4,20, 8, 8, 8, 4, 4, 8, 4,
/* 1 */  4,12, 8, 8, 4, 4, 8, 4,12, 8, 8, 8, 4, 4, 8, 4,
/* 2 */  8,12, 8, 8, 4, 4, 8, 4, 8, 8, 8, 8, 4, 4, 8, 4,
/* 3 */  8,12, 8, 8,12,12,12, 4, 8, 8, 8, 8, 4, 4, 8, 4,
/* 4 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 5 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 6 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 7 */  8, 8, 8, 8, 8, 8, 4, 8, 4, 4, 4, 4, 4, 4, 8, 4,
/* 8 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 9 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* A */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* B */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* C */  8,12,12,16,12,16, 8,16, 8,16,12, 4,12,24, 8,16,
/* D */  8,12,12, 0,12,16, 8,16, 8,16,12, 0,12, 0, 8,16,
/* E */ 12,12, 8, 0, 0,16, 8,16,16, 4,16, 0, 0, 0, 8,16,
/* F */ 12,12, 8, 4, 0,16, 8,16,12, 8,16, 4, 0, 0, 8,16,
};

UInt8[256] taken_latencies = {
     /*  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F */
/* 0 */  4,12, 8, 8, 4, 4, 8, 4,20, 8, 8, 8, 4, 4, 8, 4,
/* 1 */  4,12, 8, 8, 4, 4, 8, 4,12, 8, 8, 8, 4, 4, 8, 4,
/* 2 */ 12,12, 8, 8, 4, 4, 8, 4,12, 8, 8, 8, 4, 4, 8, 4,
/* 3 */ 12,12, 8, 8,12,12,12, 4,12, 8, 8, 8, 4, 4, 8, 4,
/* 4 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 5 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 6 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 7 */  8, 8, 8, 8, 8, 8, 4, 8, 4, 4, 4, 4, 4, 4, 8, 4,
/* 8 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* 9 */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* A */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* B */  4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
/* C */ 20,12,16,16,24,16, 8,16,20,16,16, 4,24,24, 8,16,
/* D */ 20,12,16, 0,24,16, 8,16,20,16,16, 0,24, 0, 8,16,
/* E */ 12,12, 8, 0, 0,16, 8,16,16, 4,16, 0, 0, 0, 8,16,
/* F */ 12,12, 8, 4, 0,16, 8,16,12, 8,16, 4, 0, 0, 8,16,
};

fn void print_inst(System* system, UInt16 pc) {
  UInt8 inst = system.read(pc, true);
  if (inst == 0xCB) {
    inst = system.read(pc + 1, true);
    io::printfn(mnemonics_CB[inst]);
  }
  else {
    if (inst_size[inst] == 1) {
      io::printfn(mnemonics[inst]);
    }
    else if (inst_size[inst] == 2) {
      UInt8 data = system.read(pc + 1, true);
      io::printfn(mnemonics[inst], data);
    }
    else if (inst_size[inst] == 3) {
      UInt16 data = system.read16(pc + 1, true);
      io::printfn(mnemonics[inst], data);
    }
  }
}

UInt8[256] inst_size = {
     /*  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F */
/* 0 */  1, 3, 1, 1, 1, 1, 2, 1, 3, 1, 1, 1, 1, 1, 2, 1,
/* 1 */  2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,
/* 2 */  2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,
/* 3 */  2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,
/* 4 */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* 5 */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* 6 */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* 7 */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* 8 */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* 9 */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* A */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* B */  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
/* C */  1, 1, 3, 3, 3, 1, 2, 1, 1, 1, 3, 2, 3, 3, 2, 1,
/* D */  1, 1, 3, 1, 3, 1, 2, 1, 1, 1, 3, 1, 3, 1, 2, 1,
/* E */  2, 1, 1, 1, 1, 1, 2, 1, 2, 1, 3, 1, 1, 1, 2, 1,
/* F */  2, 1, 1, 1, 1, 1, 2, 1, 2, 1, 3, 1, 1, 1, 2, 1,
};

String[256] mnemonics = {
    "nop","ld bc, %04x","ld (bc), a","inc bc","inc b","dec b","ld b, %04x","rlca","ld (%04x), sp","add hl, bc","ld a, (bc)","dec bc","inc c","dec c","ld c, %04x","rrca",
    "stop 0","ld de, %04x","ld (de), a","inc de","inc d","dec d","ld d, %04x","rla","jr %04x","add hl, de","ld a, (de)","dec de","inc e","dec e","ld e, %04x","rra ",
    "jr nz, %04x","ld hl, %04x","ld (hl+), a","inc hl","inc h","dec h","ld h, %04x","daa","jr z, %04x","add hl, hl","ld a, (hl+)","dec hl","inc l","dec l","ld l, %04x","cpl",
    "jr nc, %04x","ld sp, %04x","ld (hl-), a","inc sp","inc (hl)","dec (hl)","ld (hl),%04x","scf","jr c, %04x","add hl, sp","ld a, (hl-)","dec sp","inc a","dec a","ld a, %04x","ccf",
    "ld b, b","ld b, c","ld b, d","ld b, e","ld b, h","ld b, l","ld b, (hl)","ld b, a","ld c, b","ld c, c","ld c, d","ld c, e","ld c, h","ld c, l","ld c, (hl)","ld c, a",
    "ld d, b","ld d, c","ld d, d","ld d, e","ld d, h","ld d, l","ld d, (hl)","ld d, a","ld e, b","ld e, c","ld e, d","ld e, e","ld e, h","ld e, l","ld e, (hl)","ld e, a",
    "ld h, b","ld h, c","ld h, d","ld h, e","ld h, h","ld h, l","ld h, (hl)","ld h, a","ld l, b","ld l, c","ld l, d","ld l, e","ld l, h","ld l, l","ld l, (hl)","ld l, a",
    "ld (hl), b","ld (hl), c","ld (hl),d","ld (hl),e","ld (hl),h","ld (hl),l","halt","ld (hl),a","ld a,b","ld a,c","ld a,d","ld a,e","ld a,h","ld a,l","ld a,(hl)","ld a,a",
    "add a, b","add a, c","add a, d","add a, e","add a, h","add a, l","add a, (hl)","add a, a","adc a, b","adc a, c","adc a, d","adc a, e","adc a, h","adc a, l","adc a, (hl)","adc a, a",
    "sub b","sub c","sub d","sub e","sub h","sub l","sub (hl)","sub a","sbc a, b","sbc a, c","sbc a, d","sbc a, e","sbc a, h","sbc a, l","sbc a, (hl)","sbc a, a",
    "and b","and c","and d","and e","and h","and l","and (hl)","and a","xor b","xor c","xor d","xor e","xor h","xor l","xor (hl)","xor a",
    "or b","or c","or d","or e","or h","or l","or (hl)","or a","cp b","cp c","cp d","cp e","cp h","cp l","cp (hl)","cp a",
    "ret nz","pop bc","jp nz, %04x","jp %04x","call nz, %04x","push bc","add a,%04x","rst 00h","ret z","ret","jp z, %04x","prefix cb","call z,%04x","call %04x","adc a,%04x","rst 08h",
    "ret nc","pop de","jp nc, %04x","ud","call nc, %04x","push de","sub %04x","rst 10h","ret c","reti","jp c, %04x","ud","call c, %04x","ud","sbc a, %04x","rst 18h",
    "ld (ff00+%04x), a","pop hl","ld (ff00+c), a","ud","ud","push hl","and %04x","rst 20h","add sp, %04x","jp (hl)","ld (%04x), a","ud","ud","ud","xor %04x","rst 28h",
    "ld a,(ff00+%04x)","pop af","ld a,(ff00+c)","di","ud","push af","or %04x","rst 30h","ld hl, sp+%04x","ld sp,hl","ld a, (%04x)","ei","ud","ud","cp %04x","rst 38h",
};

String[256] mnemonics_CB = {
    "rlc b","rlc c","rlc d","rlc e","rlc h","rlc l","rlc (hl)","rlc a","rrc b","rrc c","rrc d","rrc e","rrc h","rrc l","rrc (hl)","rrc a",
    "rl b","rl c","rl d","rl e","rl h","rl l","rl (hl)","rl a","rr b","rr c","rr d","rr e","rr h","rr l","rr (hl)","rr a",
    "sla b","sla c","sla d","sla e","sla h","sla l","sla (hl)","sla a","sra b","sra c","sra d","sra e","sra h","sra l","sra (hl)","sra a",
    "swap b","swap c","swap d","swap e","swap h","swap l","swap (hl)","swap a","srl b","srl c","srl d","srl e","srl h","srl l","srl (hl)","srl a",
    "bit 0, b","bit 0, c","bit 0, d","bit 0, e","bit 0, h","bit 0, l","bit 0, (hl)","bit 0, a","bit 1, b","bit 1, c","bit 1, d","bit 1, e","bit 1, h","bit 1, l","bit 1, (hl)","bit 1, a",
    "bit 2, b","bit 2, c","bit 2, d","bit 2, e","bit 2, h","bit 2, l","bit 2, (hl)","bit 2, a","bit 3, b","bit 3, c","bit 3, d","bit 3, e","bit 3, h","bit 3, l","bit 3, (hl)","bit 3, a",
    "bit 4, b","bit 4, c","bit 4, d","bit 4, e","bit 4, h","bit 4, l","bit 4, (hl)","bit 4, a","bit 5, b","bit 5, c","bit 5, d","bit 5, e","bit 5, h","bit 5, l","bit 5, (hl)","bit 5, a",
    "bit 6, b","bit 6, c","bit 6, d","bit 6, e","bit 6, h","bit 6, l","bit 6, (hl)","bit 6, a","bit 7, b","bit 7, c","bit 7, d","bit 7, e","bit 7, h","bit 7, l","bit 7, (hl)","bit 7, a",
    "res 0, b","res 0, c","res 0, d","res 0, e","res 0, h","res 0, l","res 0, (hl)","res 0, a","res 1, b","res 1, c","res 1, d","res 1, e","res 1, h","res 1, l","res 1, (hl)","res 1, a",
    "res 2, b","res 2, c","res 2, d","res 2, e","res 2, h","res 2, l","res 2, (hl)","res 2, a","res 3, b","res 3, c","res 3, d","res 3, e","res 3, h","res 3, l","res 3, (hl)","res 3, a",
    "res 4, b","res 4, c","res 4, d","res 4, e","res 4, h","res 4, l","res 4, (hl)","res 4, a","res 5, b","res 5, c","res 5, d","res 5, e","res 5, h","res 5, l","res 5, (hl)","res 5, a",
    "res 6, b","res 6, c","res 6, d","res 6, e","res 6, h","res 6, l","res 6, (hl)","res 6, a","res 7, b","res 7, c","res 7, d","res 7, e","res 7, h","res 7, l","res 7, (hl)","res 7, a",
    "set 0, b","set 0, c","set 0, d","set 0, e","set 0, h","set 0, l","set 0, (hl)","set 0, a","set 1, b","set 1, c","set 1, d","set 1, e","set 1, h","set 1, l","set 1, (hl)","set 1, a",
    "set 2, b","set 2, c","set 2, d","set 2, e","set 2, h","set 2, l","set 2, (hl)","set 2, a","set 3, b","set 3, c","set 3, d","set 3, e","set 3, h","set 3, l","set 3, (hl)","set 3, a",
    "set 4, b","set 4, c","set 4, d","set 4, e","set 4, h","set 4, l","set 4, (hl)","set 4, a","set 5, b","set 5, c","set 5, d","set 5, e","set 5, h","set 5, l","set 5, (hl)","set 5, a",
    "set 6, b","set 6, c","set 6, d","set 6, e","set 6, h","set 6, l","set 6, (hl)","set 6, a","set 7, b","set 7, c","set 7, d","set 7, e","set 7, h","set 7, l","set 7, (hl)","set 7, a"
};