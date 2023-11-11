module mappers::nomapper;

import types;
import cart;

distinct NoMapper (Mapper) = UInt8;

fn void NoMapper.init(&mapper) @dynamic {}

fn UInt32 NoMapper.calculateAddr(&mapper, Cart* cart, UInt16 addr) @dynamic {
  return addr;
}

fn UInt8 NoMapper.read(&mapper, Cart* cart, UInt16 addr) @dynamic {
  return cart.cart[addr];
}

fn void NoMapper.write(&mapper, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  return;
}

fn UInt8 NoMapper.ram_read(&mapper, Cart* cart, UInt16 addr) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return 0xff;
  return cart.ram[addr];
}

fn void NoMapper.ram_write(&mapper, Cart* cart, UInt16 addr, UInt8 value) @dynamic {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return;
  cart.ram[addr] = value;
}