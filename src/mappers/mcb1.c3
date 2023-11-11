module mappers::mcb1;

import types;
import cart;

struct Mapper_MCB1 (Mapper) {
  bool enabled_ram;
  UInt8 low_bank;
  UInt8 high_bank;
  bool advanced_banking_mode;
}

import std::io;

fn void Mapper_MCB1.init(&mcb1) @dynamic {
  mcb1.enabled_ram = false;
  mcb1.low_bank = 0;
  mcb1.high_bank = 0;
  mcb1.advanced_banking_mode = false;
}

fn UInt32 Mapper_MCB1.calculateAddr(&mcb1, Cart* cart, UInt16 addr) @dynamic {
  UInt8 high_map = mcb1.high_bank;
  switch(cart.header.rom_size) {
    case cart::ROM_512_KIB:
    case cart::ROM_1_MB: high_map = 0x00;
    case cart::ROM_2_MB: high_map &= 0x01;
    case cart::ROM_4_MB: if (high_map > 0x10) high_map = 0x10;
    case cart::ROM_8_MB: ;
  }
  UInt32 full_addr = addr;
  if (addr <= 0x3fff) {
    if (mcb1.advanced_banking_mode) {
      full_addr = (full_addr & 0x3fff) | (high_map << 19);
    }
  }
  else  {
    full_addr = (full_addr & 0x3fff) | (high_map << 19) | (mcb1.low_bank << 14);
    if (full_addr < 0x4000) full_addr += 0x4000;
  }
  return full_addr;
}

fn UInt8 Mapper_MCB1.read(&mcb1, Cart* cart, UInt16 addr) @dynamic {
  //io::printfn("[MCB1] Wants to read %04x", addr);
  //if (full_addr != addr) io::printfn("[Bank: %02x %02x]Accessing Banked %04x -> %06x", cart.high_bank, cart.low_bank, addr, full_addr);
  //io::printfn("[MCB1] Reading %02x from %04x mapped to %04x", cart.cart[full_addr], addr, full_addr);
  UInt32 full_addr = mcb1.calculateAddr(cart, addr);
  return cart.cart[full_addr];
}

fn void Mapper_MCB1.write(&mcb1, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  switch(addr) {
    case 0x0000..0x1fff: 
      if ((value & 0x0A) != 0) { mcb1.enabled_ram = true; }
      else { mcb1.enabled_ram = false; }
    case 0x2000..0x3fff: 
      mcb1.low_bank = value;
    case 0x4000..0x5fff:
      mcb1.high_bank = value & 0x03;
    case 0x6000..0x7fff:
      mcb1.advanced_banking_mode = value == 0x01;
  }
}

fn UInt8 Mapper_MCB1.ram_read(&mcb1, Cart* cart, UInt16 addr) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return 0xff;
  if (!mcb1.advanced_banking_mode) return cart.ram[addr];

  UInt8 high_map = mcb1.high_bank;
  switch(cart.header.ram_size) {
    case cart::RAM_8KIB: high_map = 0x00;
    case cart::RAM_32KIB: high_map &= 0x01;
    case cart::RAM_128KIB: if (high_map > 0x10) high_map = 0x10;
    case cart::RAM_64KIB: ;
  }
  UInt32 full_addr = addr;
  full_addr = (full_addr & 0x3fff) | (high_map << 13);
  return cart.ram[full_addr];
}

fn void Mapper_MCB1.ram_write(&mcb1, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return;
  if (!mcb1.advanced_banking_mode) cart.ram[addr] = value;

  UInt8 high_map = mcb1.high_bank;
  switch(cart.header.ram_size) {
    case cart::RAM_8KIB: high_map = 0x00;
    case cart::RAM_32KIB: high_map &= 0x01;
    case cart::RAM_128KIB: if (high_map > 0x10) high_map = 0x10;
    case cart::RAM_64KIB: ;
  }
  UInt32 full_addr = addr;
  full_addr = (full_addr & 0x3fff) | (high_map << 13);
  cart.ram[full_addr] = value;
}