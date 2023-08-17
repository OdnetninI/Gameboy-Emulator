module mappers::mcb3;

import types;
import cart;

struct Mapper_MCB3 {
  bool enabled_ram;
  UInt8 low_bank;
  UInt8 high_bank;
  bool advanced_banking_mode;
}

fn void init(Cart* cart) {
  cart.mcb3.enabled_ram = false;
  cart.mcb3.low_bank = 0;
  cart.mcb3.high_bank = 0;
  cart.mcb3.advanced_banking_mode = false;
}

fn UInt8 read(Cart* cart, UInt16 addr) {
  UInt8 high_map = cart.mcb3.high_bank;
    switch(cart.header.rom_size) {
      case cart::ROM_1_MB: high_map = 0x00;
      case cart::ROM_2_MB: high_map &= 0x01;
      case cart::ROM_4_MB: if (high_map > 0x10) high_map = 0x10;
      case cart::ROM_8_MB: ;
    }
    UInt32 full_addr = addr;
    if (addr <= 0x3fff) {
      if (cart.mcb3.advanced_banking_mode) {
        full_addr = (full_addr & 0x3fff) | (high_map << 19);
      }
    }
    else  {
      full_addr = (full_addr & 0x3fff) | (high_map << 19) | (cart.mcb3.low_bank << 14);
    }
    //if (full_addr != addr) io::printfn("[Bank: %02x %02x]Accessing Banked %04x -> %06x", cart.high_bank, cart.low_bank, addr, full_addr);
    return cart.cart[full_addr];
}

fn void write(Cart* cart, UInt16 addr, UInt8 value) {
  switch(addr) {
    case 0x0000..0x1fff: 
      if ((value & 0x0A) != 0) { cart.mcb3.enabled_ram = true; }
      else { cart.mcb3.enabled_ram = false; }
    case 0x2000..0x3fff: 
      cart.mcb3.low_bank = value & 0x1f;
    case 0x4000..0x5fff:
      cart.mcb3.high_bank = value & 0x03;
    case 0x6000..0x7fff:
      cart.mcb3.advanced_banking_mode = value == 0x01;
  }
}

fn UInt8 ram_read(Cart* cart, UInt16 addr) {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return 0xff;
  if (!cart.mcb3.advanced_banking_mode) return cart.ram[addr];

  UInt8 high_map = cart.mcb3.high_bank;
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

fn void ram_write(Cart* cart, UInt16 addr, UInt8 value) {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return;
  if (!cart.mcb3.advanced_banking_mode) cart.ram[addr] = value;

  UInt8 high_map = cart.mcb3.high_bank;
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