module cart;

import types;
import system;

import mappers::nomapper;
import mappers::mcb1;
import mappers::mcb3;
import mappers::mcb5;

import std::io;

// Mappers
const UInt8 MAPPER_ROM = 0x00;
const UInt8 MAPPER_MCB1 = 0x01;
const UInt8 MAPPER_MCB1_RAM = 0x02;
const UInt8 MAPPER_MCB1_RAM_BATTERY = 0x03;
const UInt8 MAPPER_MCB2 = 0x05;
const UInt8 MAPPER_MCB2_BATTERY = 0x06;
const UInt8 MAPPER_ROM_RAM = 0x08;
const UInt8 MAPPER_ROM_RAM_BATTERY = 0x09;
const UInt8 MAPPER_MMM01 = 0x0b;
const UInt8 MAPPER_MMM01_RAM = 0x0c;
const UInt8 MAPPER_MMM01_RAM_BATTERY = 0x0d;
const UInt8 MAPPER_MCB3_TIMER_BATTERY = 0x0f;
const UInt8 MAPPER_MCB3_TIMER_RAM_BATTERY = 0x10;
const UInt8 MAPPER_MCB3 = 0x11;
const UInt8 MAPPER_MCB3_RAM = 0x12;
const UInt8 MAPPER_MCB3_RAM_BATTERY = 0x13;
const UInt8 MAPPER_MCB5 = 0x19;
const UInt8 MAPPER_MCB5_RAM = 0x1a;
const UInt8 MAPPER_MCB5_RAM_BATTERY = 0x1b;
const UInt8 MAPPER_MCB5_RUMBLE = 0x1c;
const UInt8 MAPPER_MCB5_RUMBLE_RAM = 0x1d;
const UInt8 MAPPER_MCB5_RUMBLE_RAM_BATTERY = 0x1e;
const UInt8 MAPPER_MCB6 = 0x20;
const UInt8 MAPPER_MCB7_SENSOR_RUMBLE_RAM_BATTERY = 0x22;
const UInt8 MAPPER_POCKET_CAMERA = 0xfc;
const UInt8 MAPPER_BANDAI_TAMA5 = 0xfd;
const UInt8 MAPPER_HUC3 = 0xfe;
const UInt8 MAPPER_HUC1_RAM_BATTERY = 0xff;

// ROM Sizes
const UInt8 ROM_32_KIB = 0x00;
const UInt8 ROM_64_KIB = 0x01;
const UInt8 ROM_128_KIB = 0x02;
const UInt8 ROM_256_KIB = 0x03;
const UInt8 ROM_512_KIB = 0x04;
const UInt8 ROM_1_MB = 0x05;
const UInt8 ROM_2_MB = 0x06;
const UInt8 ROM_4_MB = 0x07;
const UInt8 ROM_8_MB = 0x08;
const UInt8 ROM_1_1_MB = 0x52;
const UInt8 ROM_1_2_MB = 0x53;
const UInt8 ROM_1_5_MB = 0x54;

// RAM Sizes
const UInt8 RAM_NO_RAM = 0x00;
const UInt8 RAM_UNUSED = 0x01;
const UInt8 RAM_8KIB = 0x02;
const UInt8 RAM_32KIB = 0x03;
const UInt8 RAM_128KIB = 0x04;
const UInt8 RAM_64KIB = 0x05;

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
  String filename;
  String save_filename;
  Header header;
  UInt8[] cart;
  UInt8[] ram;
  System* system;

  // Mappers Data
  Mapper_MCB1 mcb1;
  Mapper_MCB3 mcb3;
  Mapper_MCB5 mcb5;
}

fn void Cart.init(Cart* cart, System* system) {
  cart.system = system;

  // Initialize mappers
  mappers::mcb1::init(cart);
  mappers::mcb3::init(cart);
  mappers::mcb5::init(cart);
}

fn void Cart.open(Cart* cart, String filename) {
  cart.filename = filename;
  cart.save_filename = filename.concat(".sav");
  io::printfn("Cart: %s\nSave: %s", cart.filename, cart.save_filename);
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
    case MAPPER_ROM: 
    case MAPPER_ROM_RAM:
    case MAPPER_ROM_RAM_BATTERY:
      return mappers::nomapper::read(cart, addr);

    case MAPPER_MCB1:
    case MAPPER_MCB1_RAM:
    case MAPPER_MCB1_RAM_BATTERY:
      return mappers::mcb1::read(cart, addr);

    case MAPPER_MCB3:
    case MAPPER_MCB3_RAM:
    case MAPPER_MCB3_RAM_BATTERY: 
      return mappers::mcb3::read(cart, addr);

    case MAPPER_MCB5:
    case MAPPER_MCB5_RAM:
    case MAPPER_MCB5_RAM_BATTERY:
    case MAPPER_MCB5_RUMBLE:
    case MAPPER_MCB5_RUMBLE_RAM:
    case MAPPER_MCB5_RUMBLE_RAM_BATTERY:
      return mappers::mcb5::read(cart, addr);
    
  }
  return 0xff;
}

fn void Cart.write(Cart* cart, UInt16 addr, UInt8 value) {
  switch(cart.header.cartridge_type) {
    case MAPPER_ROM: 
    case MAPPER_ROM_RAM:
    case MAPPER_ROM_RAM_BATTERY:
      mappers::nomapper::write(cart, addr, value);

    case MAPPER_MCB1:
    case MAPPER_MCB1_RAM:
    case MAPPER_MCB1_RAM_BATTERY:
      mappers::mcb1::write(cart, addr, value);

    case MAPPER_MCB3:
    case MAPPER_MCB3_RAM:
    case MAPPER_MCB3_RAM_BATTERY: 
      mappers::mcb3::write(cart, addr, value);

    case MAPPER_MCB5:
    case MAPPER_MCB5_RAM:
    case MAPPER_MCB5_RAM_BATTERY:
    case MAPPER_MCB5_RUMBLE:
    case MAPPER_MCB5_RUMBLE_RAM:
    case MAPPER_MCB5_RUMBLE_RAM_BATTERY:
      mappers::mcb5::write(cart, addr, value);
  }
}

fn UInt8 Cart.ram_read(Cart* cart, UInt16 addr) {
  switch(cart.header.cartridge_type) {
    case MAPPER_ROM: 
    case MAPPER_ROM_RAM:
    case MAPPER_ROM_RAM_BATTERY:
      return mappers::nomapper::ram_read(cart, addr);

    case MAPPER_MCB1:
    case MAPPER_MCB1_RAM:
    case MAPPER_MCB1_RAM_BATTERY:
      return mappers::mcb1::ram_read(cart, addr);

    case MAPPER_MCB3:
    case MAPPER_MCB3_RAM:
    case MAPPER_MCB3_RAM_BATTERY: 
      return mappers::mcb3::ram_read(cart, addr);

    case MAPPER_MCB5:
    case MAPPER_MCB5_RAM:
    case MAPPER_MCB5_RAM_BATTERY:
    case MAPPER_MCB5_RUMBLE:
    case MAPPER_MCB5_RUMBLE_RAM:
    case MAPPER_MCB5_RUMBLE_RAM_BATTERY:
      return mappers::mcb5::ram_read(cart, addr);
  }
  return 0xff;
}

fn void Cart.ram_write(Cart* cart, UInt16 addr, UInt8 value) {
  switch(cart.header.cartridge_type) {
    case MAPPER_ROM: 
    case MAPPER_ROM_RAM:
    case MAPPER_ROM_RAM_BATTERY:
      mappers::nomapper::ram_write(cart, addr, value);

    case MAPPER_MCB1:
    case MAPPER_MCB1_RAM:
    case MAPPER_MCB1_RAM_BATTERY:
      mappers::mcb1::ram_write(cart, addr, value);

    case MAPPER_MCB3:
    case MAPPER_MCB3_RAM:
    case MAPPER_MCB3_RAM_BATTERY: 
      mappers::mcb3::ram_write(cart, addr, value);

    case MAPPER_MCB5:
    case MAPPER_MCB5_RAM:
    case MAPPER_MCB5_RAM_BATTERY:
    case MAPPER_MCB5_RUMBLE:
    case MAPPER_MCB5_RUMBLE_RAM:
    case MAPPER_MCB5_RUMBLE_RAM_BATTERY:
      mappers::mcb5::ram_write(cart, addr, value);
  }
  cart.save();
}

fn void Cart.close(Cart* cart) {
  free(cart.cart);
}

fn void Cart.save(Cart* cart) {
  if (cart.header.ram_size == RAM_NO_RAM || cart.header.ram_size == RAM_UNUSED) return;
  io::File! save_file = io::file::open(cart.save_filename, "wb");
  save_file.write(cart.ram)!!;
  save_file.close()!!;
}

fn void Cart.load(Cart* cart) {
  /*switch(cart.header.cartridge_type) {
    case MAPPER_ROM: ;
    case MAPPER_MCB3_RAM_BATTERY: ;
    default: 
      io::printfn("Mapper type %02x not supported", cart.header.cartridge_type);
      cart.header.cartridge_type = MAPPER_MCB3_RAM_BATTERY; //MAPPER_NO_ROM; 
  }

  switch(cart.header.rom_size) {
    case ROM_32_KIB: ;
    case ROM_64_KIB: ;
    case ROM_128_KIB: ;
    case ROM_256_KIB: ;
    case ROM_512_KIB: ;
    case ROM_1_MB: ;
    case ROM_2_MB: ;
    case ROM_4_MB: ;
    case ROM_8_MB: ;
    case ROM_1_1_MB: ;
    case ROM_1_2_MB: ;
    case ROM_1_5_MB: ;
    default:
      io::printfn("ROM size %02x not supported", cart.header.rom_size);
  }*/

  switch(cart.header.ram_size) {
    case RAM_NO_RAM: cart.ram = malloc(UInt8, 0);
    case RAM_UNUSED: cart.ram = malloc(UInt8, 0);
    case RAM_8KIB: cart.ram = malloc(UInt8, 8*1024);
    case RAM_32KIB: cart.ram = malloc(UInt8, 32*1024);
    case RAM_64KIB: cart.ram = malloc(UInt8, 64*1024);
    case RAM_128KIB: cart.ram = malloc(UInt8, 128*1024);
    default:
      io::printfn("RAM size %02x not supported", cart.header.ram_size);
  }

  io::File! save_file = io::file::open(cart.save_filename, "rb");
  if (try save = save_file) {
    save.read(cart.ram)!!;
    save.close()!!;
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