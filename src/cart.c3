module cart;

import types;
import system;

import std::io;

// Mappers
const UInt8 MAPPER_NO_ROM = 0x00;
const UInt8 MAPPER_MCB3_RAM_BATTERY = 0x13;

// ROM Sizes
const UInt8 ROM_32_KIB = 0x00;
const UInt8 ROM_1_MB = 0x05;
const UInt8 ROM_2_MB = 0x06;
const UInt8 ROM_4_MB = 0x07;
const UInt8 ROM_8_MB = 0x08;

// RAM Sizes
const UInt8 RAM_NO_RAM = 0x00;
const UInt8 RAM_UNUSED = 0x01;
const UInt8 RAM_8KIB = 0x02;
const UInt8 RAM_32KIB = 0x03;

struct Header {
  UInt8[16] title;
  UInt8[4] manufacturer;
  UInt8 gbc_flag;
  UInt8 old_license;
  UInt8 header_checksum;
  UInt16 global_checksum;
  UInt8 mask_rom_version;
  UInt8 region;
  UInt8 cartridge_type;
  UInt8 rom_size;
  UInt8 ram_size;
}

struct Cart {
  UInt8[] cart;
  Header header;
  System* system;

  UInt8[0x2000] ram;
  bool enabled_ram;
  UInt8 low_bank;
  UInt8 high_bank;
  bool advanced_banking_mode;
}

fn void Cart.init(Cart* cart, System* system) {
  cart.system = system;
  cart.enabled_ram = false;
  cart.low_bank = 0x00;
  cart.high_bank = 0x00;
  cart.advanced_banking_mode = false;
}

fn void Cart.open(Cart* cart, String filename) {
  io::File! game_file = io::file::open(filename, "rb");
  usz size = game_file.seek(0, END)!!;
  io::printfn("Cart size: %d", size);
  cart.cart = malloc(UInt8, size);
  game_file.seek(0, SET)!!;
  game_file.read(cart.cart)!!;
  game_file.close()!!;

  for (UInt16 i = 0x134; i <= 0x0143; ++i) { cart.header.title[i - 0x0134] = cart.cart[i]; }
  for (UInt16 i = 0x13F; i <= 0x0142; ++i) { cart.header.manufacturer[i - 0x013F] = cart.cart[i]; }
  cart.header.gbc_flag = cart.cart[0x0143];
  cart.header.old_license = cart.cart[0x014B];
  cart.header.header_checksum = cart.cart[0x014D];
  cart.header.global_checksum = cart.cart[0x014E] << 8 | cart.cart[0x014F];
  cart.header.mask_rom_version = cart.cart[0x014C];
  cart.header.region = cart.cart[0x014A];
  cart.header.cartridge_type = cart.cart[0x0147];
  cart.header.rom_size = cart.cart[0x0148];
  cart.header.ram_size = cart.cart[0x0149];
}

fn UInt8 Cart.read(Cart* cart, UInt16 addr) {
  switch(cart.header.cartridge_type) {
    case MAPPER_NO_ROM: return cart.cart[addr];
    case MAPPER_MCB3_RAM_BATTERY:
    UInt8 high_map = cart.high_bank;
    switch(cart.header.rom_size) {
      case ROM_1_MB: high_map = 0x00;
      case ROM_2_MB: high_map &= 0x01;
      case ROM_4_MB: if (high_map > 0x10) high_map = 0x10;
      case ROM_8_MB: ;
    }
      UInt32 full_addr = addr;
      if (addr <= 0x3fff) {
        if (cart.advanced_banking_mode) {
          full_addr = (full_addr & 0x3fff) | (high_map << 19);
        }
      }
      else  {
        full_addr = (full_addr & 0x3fff) | (high_map << 19) | (cart.low_bank << 14);
      }
      //if (full_addr != addr) io::printfn("[Bank: %02x %02x]Accessing Banked %04x -> %06x", cart.high_bank, cart.low_bank, addr, full_addr);
      return cart.cart[full_addr];
  }
  return 0xff;
}

fn void Cart.write(Cart* cart, UInt16 addr, UInt8 value) {
  switch(cart.header.cartridge_type) {
    case MAPPER_NO_ROM: return;
    case MAPPER_MCB3_RAM_BATTERY: 
      switch(addr) {
        case 0x0000..0x1fff: 
          if ((value & 0x0A) != 0) { cart.enabled_ram = true; }
          else { cart.enabled_ram = false; }
        case 0x2000..0x3fff: 
          cart.low_bank = value & 0x1f;
        case 0x4000..0x5fff:
          cart.high_bank = value & 0x03;
        case 0x6000..0x7fff:
          cart.advanced_banking_mode = value == 0x01;
      }
  }
}

fn UInt8 Cart.ram_read(Cart* cart, UInt16 addr) {
  if (cart.header.ram_size == RAM_NO_RAM || cart.header.ram_size == RAM_UNUSED) return 0xff;
  if (!cart.enabled_ram) return 0xff;
  return cart.ram[addr];
}

fn void Cart.ram_write(Cart* cart, UInt16 addr, UInt8 value) {
  if (cart.header.ram_size == RAM_NO_RAM || cart.header.ram_size == RAM_UNUSED) return;
  if (!cart.enabled_ram) return;
  cart.ram[addr] = value;
}

fn void Cart.close(Cart* cart) {
  free(cart.cart);
}

fn void Cart.load(Cart* cart) {
  switch(cart.header.cartridge_type) {
    case MAPPER_NO_ROM: 
      if (cart.header.rom_size != ROM_32_KIB) {
        io::printfn("Found ROM size %02x with no mapper", cart.header.rom_size);
      }
    case MAPPER_MCB3_RAM_BATTERY:
      if (cart.header.ram_size == RAM_NO_RAM) {
        io::printfn("MCB3 Mapper with Ram and Battery, but Cart does not have RAM");
      }
      if (cart.header.ram_size == ROM_32_KIB) {
        io::printfn("MCB3 Mapper with Ram and Battery, but Cart only has 2 banks");
      }
    default: 
      io::printfn("Mapper type %02x not supported", cart.header.cartridge_type);
      return;
  }

  switch(cart.header.rom_size) {
    case ROM_32_KIB: ;
    case ROM_1_MB: ;
    default:
      io::printfn("ROM size %02x not supported", cart.header.rom_size);
      return;
  }

  switch(cart.header.ram_size) {
    case RAM_NO_RAM: ;
    case RAM_UNUSED: ;
    case RAM_32KIB: ;
    default:
      io::printfn("RAM size %02x not supported", cart.header.ram_size);
      return;
  }
}

fn void Cart.printHeader(Cart* cart) {
  io::printfn("------ CART HEADER ------");
  io::printf("Title: "); for (UInt8 i = 0; i < cart.header.title.len; ++i) io::printf("%c", cart.header.title[i]); io::printfn("");
  io::printf("Manufacturer: "); for (UInt8 i = 0; i < cart.header.manufacturer.len; ++i) io::printf("%c", cart.header.manufacturer[i]); io::printfn("");
  io::printf("GBC Flag: "); io::printfn("%s", cart.header.gbc_flag == 0xC0 ? "GBC Only" : cart.header.gbc_flag == 0x80 ? "GBC Enhancements" : "None"); // Check also for PGB
  io::printf("Old License: "); io::printfn("%02x", cart.header.old_license);
  io::printf("Header checksum: "); io::printfn("%02x", cart.header.header_checksum);
  io::printf("Global checksum: "); io::printfn("%04x", cart.header.global_checksum);
  io::printf("Mask Rom version: "); io::printfn("%02x", cart.header.mask_rom_version);
  io::printf("Region: "); io::printfn("%s", cart.header.region == 0x00 ? "Japan & World" : cart.header.region == 0x01 ? "Non-Japan" : "Unknown");
  io::printf("Type: "); io::printfn("%02x", cart.header.cartridge_type);
  io::printf("Rom Size: "); io::printfn("%02x", cart.header.rom_size);
  io::printf("Ram Size: "); io::printfn("%02x", cart.header.ram_size);
  io::printfn("-------------------------");
}