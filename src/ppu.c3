module ppu;

import std::io;

import types;

import system;

struct PpuRegs {
  bitstruct : UInt8 @overlap {
    UInt8 lcdc :  0..7;
    bool lcd_control : 7;
    bool window_tile_map_select : 6;
    bool window_display : 5;
    bool bg_window_tile_select : 4;
    bool bg_tile_map_select : 3;
    bool obj_size : 2;
    bool obj_show : 1;
    bool bg_window_show : 0;
  }
  bitstruct : UInt8 @overlap {
    UInt8 stat : 0..7;
    bool lyc_ly_coincidence : 6;
    bool mode_10 : 5;
    bool mode_01 : 4;
    bool mode_00 : 3;
    bool lyc_lcdcly_coincidence : 2;
    UInt8 mode_flag : 0..1;
  }
  UInt8 scy;
  UInt8 scx;
  UInt8 ly;
  UInt8 lyc;
  UInt8 dma;
  bitstruct : UInt8 @overlap {
    UInt8 bgp : 0..7;
    UInt8 color00 : 0..1;
    UInt8 color01 : 2..3;
    UInt8 color10 : 4..5;
    UInt8 color11 : 6..7;
  }
  UInt8 obp0;
  UInt8 obp1;
  UInt8 wy;
  UInt8 wx;
}

struct Ppu {
  System* system;
  UInt8 mode;
  PpuRegs regs;
}

enum Mode {
  H_BLANK, /* To fill 456 Ticks in total since OAM Scan */
  V_BLANK, /* 10 scanlines of 456 Ticks */
  OAM_SCAN, /* 80 Ticks, checking every 2 */ /* <--- start here */
  DRAWING, /* Variable */
}

fn UInt8 Ppu.read(Ppu* ppu, UInt16 addr) {
  switch (addr) {
    case 0xFF40: return ppu.regs.lcdc;
    case 0xFF41: return ppu.regs.stat;
    case 0xFF42: return ppu.regs.scy;
    case 0xFF43: return ppu.regs.scx;
    case 0xFF44: return ppu.regs.ly;
    case 0xFF45: return ppu.regs.lyc;
    case 0xFF46: return ppu.regs.dma;
    case 0xFF47: return ppu.regs.bgp;
    case 0xFF48: return ppu.regs.obp0;
    case 0xFF49: return ppu.regs.obp1;
    case 0xFF4A: return ppu.regs.wy;
    case 0xFF4B: return ppu.regs.wx;
    default:
      io::printfn("PPU read to %04x not mapped", addr);
      return 0;
  }
}

fn void Ppu.write(Ppu* ppu, UInt16 addr, UInt8 value) {
  switch (addr) {
    case 0xFF40: ppu.regs.lcdc = value;
    case 0xFF41: ppu.regs.stat = value;
    case 0xFF42: ppu.regs.scy = value;
    case 0xFF43: ppu.regs.scx = value;
    case 0xFF44: ppu.regs.ly = 0;
    case 0xFF45: ppu.regs.lyc = value;
    case 0xFF46: 
      // DMA Copy
      ppu.regs.dma = value;
      UInt16 start_addr = value << 8;
      for (UInt16 i = 0; i < 0x9f; ++i) {
        UInt8 data = ppu.system.mem.read(start_addr + i);
        ppu.system.mem.write(0xFE00 + i, data);
      }
    case 0xFF47: ppu.regs.bgp = value;
    case 0xFF48: ppu.regs.obp0 = value;
    case 0xFF49: ppu.regs.obp1 = value;
    case 0xFF4A: ppu.regs.wy = value;
    case 0xFF4B: ppu.regs.wx = value;
    default:
      io::printfn("PPU write to %04x not mapped", addr);
  }
}

fn void Ppu.init(Ppu* ppu, System* system) {
  ppu.system = system;
  ppu.regs.lcdc = 0x91;
  ppu.regs.ly = 0;
  ppu.regs.scx = 0;
  ppu.regs.scy = 0;
  ppu.regs.wx = 0;
  ppu.regs.wy = 0;
}

fn UInt8 Ppu.remapColor(Ppu* ppu, UInt8 color) {
  switch(color) {
    case 0b00: return ppu.regs.color00;
    case 0b01: return ppu.regs.color01;
    case 0b10: return ppu.regs.color10;
    case 0b11: return ppu.regs.color11;
    default:
      io::printfn("Invalid pixel data %02x", color);
      return 0;
  }
}

fn void Ppu.tick(Ppu* ppu, UInt64 tick) {
  UInt64 step = (tick + 1) % 457;

  if (ppu.regs.ly >= 144) {
    ppu.regs.mode_flag = 0b01;
  }
  else if (step < 80) {
    ppu.regs.mode_flag = 0b10;
  }
  else if (step < 371) {
    ppu.regs.mode_flag = 0b11;
  }
  else if (step < 456) {
    ppu.regs.mode_flag = 0b00;
  }


  if (step == 0) {
    //io::printfn("PPU processing line 0x%02x", ppu.regs.ly);
    // LYC == LC or LYC != LC
    if (ppu.regs.lyc_lcdcly_coincidence) {
      ppu.regs.lyc_ly_coincidence = ppu.regs.lyc == ppu.regs.ly;
    }
    else {
      ppu.regs.lyc_ly_coincidence = ppu.regs.lyc != ppu.regs.ly;
    }

    if (ppu.regs.ly < 144) {

      UInt8 sx = ppu.regs.scx;
      UInt8 sy = ppu.regs.scy;
      UInt8 wx = ppu.regs.wx - 7;
      UInt8 wy = ppu.regs.wy;

      bool unsig = true;
      UInt16 tileData = 0x8000;
      if (!ppu.regs.bg_window_tile_select) {
        unsig = false;
        tileData = 0x8800;
      }

      UInt16 backgroundMem = 0x9800;
      if(ppu.regs.bg_tile_map_select) {
        backgroundMem = 0x9C00;
      }

      UInt8 yPos = sy + ppu.regs.ly;
      UInt16 tileRow = ((UInt8)(yPos / 8)) * 32;
    
      for (UInt8 x = 0; x < 160; ++x) {
        //ppu.system.lcd.framebuffer[ppu.regs.ly][x] = ppu.system.lcd.framebuffer[ppu.regs.ly][x] == 0 ? 1 : 0;
        UInt8 xPos = x + sx;
        UInt16 tileCol = xPos / 8;
        Int16 tileNum;
        UInt16 tileAddress = backgroundMem + tileRow + tileCol;
        tileNum = (UInt8)ppu.system.mem.read(tileAddress);
        if (!unsig) tileNum = (Int8)ppu.system.mem.read(tileAddress);

        UInt16 tileLocation = tileData;
        if (unsig) { tileLocation += (tileNum * 16); }
        else { tileLocation += ((tileNum + 128) * 16); }
        //io::printfn("TileAddr %04x", tileLocation);

        UInt8 line = yPos % 8;
        line *= 2;
        UInt8 data1 = ppu.system.mem.read((UInt16)(tileLocation + line));
        UInt8 data2 = ppu.system.mem.read((UInt16)(tileLocation + line + 1));

        //io::printfn("Tile at %04x is %02x %02x", tileLocation + line, data1, data2);

        int colourBit = xPos % 8;
        colourBit -= 7;
        colourBit *= -1;

        UInt8 colourNum = ((data2 >> colourBit) & 0x1);
        colourNum <<= 1;
        colourNum |= ((data1 >> colourBit) & 0x1);

        //io::printfn("Color is %02x", colourNum);

        ppu.system.lcd.framebuffer[ppu.regs.ly][x] = ppu.remapColor(colourNum);
      }
      //ppu.system.lcd.redraw();
    }
    ppu.regs.ly = (ppu.regs.ly + 1) % 154;
    if (ppu.regs.ly == 144) {
      ppu.system.lcd.redraw();
      UInt8 interrupt = ppu.system.mem.read(0xFF0F);
      interrupt = interrupt | (1 << 0); // VBLANK interrupt
      ppu.system.mem.write(0xFF0F, interrupt);
      //io::printfn("Sending VBLANK interrupt");
    }

    if (ppu.regs.ly == 0) {
      /*
      UInt16 tileData = 0x8000;
      if (!ppu.regs.bg_window_tile_select) {
        tileData = 0x8800;
      }

      UInt16 backgroundMem = 0x9800;
      if(ppu.regs.bg_tile_map_select) {
        backgroundMem = 0x9C00;
      }
      io::printfn("Tiledata 0x%04:", tileData);
      for(int i = 0; i < 512; ++i) {
        io::printf("%02x ", ppu.system.mem.read((UInt16)(tileData + i)));
      } 
      io::printfn("");
      io::printfn("BackgroundMem 0x%04:", backgroundMem);
      for(int i = 0; i < 512; ++i) {
        io::printf("%02x ", ppu.system.mem.read((UInt16)(backgroundMem + i)));
      } 
      io::printfn("");
      io::printfn("");
      */
    }
  }
}