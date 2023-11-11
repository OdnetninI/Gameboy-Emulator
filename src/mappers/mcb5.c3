module mappers::mcb5;

import types;
import cart;

struct Mapper_MCB5 (Mapper) {
  bool enabled_ram;
  UInt8 low_bank;
  UInt8 high_bank;
  UInt8 ram_bank;
}

fn void Mapper_MCB5.init(&mcb5) @dynamic {
  mcb5.enabled_ram = false;
  mcb5.low_bank = 0;
  mcb5.high_bank = 0;
  mcb5.ram_bank = 0;
}

fn UInt32 Mapper_MCB5.calculateAddr(&mcb5, Cart* cart, UInt16 addr) @dynamic {
  if (addr < 0x4000) return addr;
  UInt8 high_map = mcb5.high_bank;
    switch(cart.header.rom_size) {
      case cart::ROM_1_MB: high_map = 0x00;
      case cart::ROM_2_MB: high_map &= 0x01;
      case cart::ROM_4_MB: if (high_map > 0x10) high_map = 0x10;
      case cart::ROM_8_MB: ;
    }
    UInt32 full_addr = addr;
    full_addr = (full_addr & 0x3fff) | (high_map << 19) | (mcb5.low_bank << 14);
    return full_addr;
}

fn UInt8 Mapper_MCB5.read(&mcb5, Cart* cart, UInt16 addr) @dynamic {
  if (addr < 0x4000) return cart.cart[addr];
  UInt8 high_map = mcb5.high_bank;
    switch(cart.header.rom_size) {
      case cart::ROM_1_MB: high_map = 0x00;
      case cart::ROM_2_MB: high_map &= 0x01;
      case cart::ROM_4_MB: if (high_map > 0x10) high_map = 0x10;
      case cart::ROM_8_MB: ;
    }
    UInt32 full_addr = addr;
    full_addr = (full_addr & 0x3fff) | (high_map << 19) | (mcb5.low_bank << 14);
    return cart.cart[full_addr];
}

fn void Mapper_MCB5.write(&mcb5, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  switch(addr) {
    case 0x0000..0x1fff: 
      if ((value & 0x0A) != 0) { mcb5.enabled_ram = true; }
      else { mcb5.enabled_ram = false; }
    case 0x2000..0x2fff: 
      mcb5.low_bank = value;
    case 0x3000..0x3fff:
      mcb5.high_bank = value & 0x01;
    case 0x4000..0x5fff:
      mcb5.ram_bank = value;
  }
}

fn UInt8 Mapper_MCB5.ram_read(&mcb5, Cart* cart, UInt16 addr) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return 0xff;
  UInt32 full_addr = addr;
  full_addr = (full_addr & 0x3fff) | (mcb5.ram_bank << 13);
  return cart.ram[full_addr];
}

fn void Mapper_MCB5.ram_write(&mcb5, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return;
  UInt32 full_addr = addr;
  full_addr = (full_addr & 0x3fff) | (mcb5.ram_bank << 13);
  cart.ram[full_addr] = value;
}