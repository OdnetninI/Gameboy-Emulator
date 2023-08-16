module mappers::nomapper;

import types;
import cart;

fn UInt8 read(Cart* cart, UInt16 addr) {
  return cart.cart[addr];
}

fn void write(Cart* cart, UInt16 addr, UInt8 value) {
  return;
}

fn UInt8 ram_read(Cart* cart, UInt16 addr) {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return 0xff;
  return cart.ram[addr];
}

fn void ram_write(Cart* cart, UInt16 addr, UInt8 value) {
  if (cart.header.ram_size == cart::RAM_NO_RAM || cart.header.ram_size == cart::RAM_UNUSED) return;
  cart.ram[addr] = value;
}