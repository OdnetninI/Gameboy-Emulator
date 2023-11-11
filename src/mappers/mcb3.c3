module mappers::mcb3;

import types;
import cart;

struct Mapper_MCB3 (Mapper) {
  bool enabled_ram;
  UInt8 bank;
  UInt8 ram_bank;
}

fn void Mapper_MCB3.init(&mcb3) @dynamic {
  mcb3.enabled_ram = false;
  mcb3.bank = 0;
  mcb3.ram_bank = 0;
}

fn UInt32 Mapper_MCB3.calculateAddr(&mcb3, Cart* cart, UInt16 addr) @dynamic {
  UInt32 full_addr = addr;
  if (addr <= 0x3fff) {
    full_addr = full_addr & 0x3fff;
  }
  else  {
    full_addr = (full_addr & 0x3fff) | (mcb3.bank << 14);
  }
  return full_addr;
}

fn UInt8 Mapper_MCB3.read(&mcb3, Cart* cart, UInt16 addr) @dynamic {
  UInt32 full_addr = mcb3.calculateAddr(cart, addr);
  return cart.cart[full_addr];
}

fn void Mapper_MCB3.write(&mcb3, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  switch(addr) {
    case 0x0000..0x1fff: 
      if ((value & 0x0A) != 0) { mcb3.enabled_ram = true; }
      else { mcb3.enabled_ram = false; }
    case 0x2000..0x3fff: 
      mcb3.bank = value & 0x7f;
    case 0x4000..0x5fff:
      if (value <= 0x03) mcb3.ram_bank = value;
    case 0x6000..0x7fff:
      break;
  }
}

fn UInt8 Mapper_MCB3.ram_read(&mcb3, Cart* cart, UInt16 addr) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return 0xff;
  UInt32 full_addr = addr;
  full_addr = (full_addr & 0x3fff) | (mcb3.ram_bank << 13);
  return cart.ram[full_addr];
}

fn void Mapper_MCB3.ram_write(&mcb3, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return;
  UInt32 full_addr = addr;
  full_addr = (full_addr & 0x3fff) | (mcb3.ram_bank << 13);
  cart.ram[full_addr] = value;
}