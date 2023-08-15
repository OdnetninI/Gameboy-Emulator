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
    UInt8 bg_color00 : 0..1;
    UInt8 bg_color01 : 2..3;
    UInt8 bg_color10 : 4..5;
    UInt8 bg_color11 : 6..7;
  }
  bitstruct : UInt8 @overlap {
    UInt8 obp0 : 0..7;
    UInt8 obp0_color00 : 0..1;
    UInt8 obp0_color01 : 2..3;
    UInt8 obp0_color10 : 4..5;
    UInt8 obp0_color11 : 6..7;
  }
  bitstruct : UInt8 @overlap {
    UInt8 obp1 : 0..7;
    UInt8 obp1_color00 : 0..1;
    UInt8 obp1_color01 : 2..3;
    UInt8 obp1_color10 : 4..5;
    UInt8 obp1_color11 : 6..7;
  }
  UInt8 wy;
  UInt8 wx;
}

struct Oam {
  UInt8 y;
  UInt8 x;
  UInt8 tile;

  bitstruct : UInt8 @overlap {
    UInt8 flags : 0..7;
    bool priority : 7;
    bool yflip : 6;
    bool xflip : 5;
    bool pallette : 4;
  }
}

struct Ppu {
  System* system;
  UInt8 mode;
  PpuRegs regs;

  UInt8[0x2000] vram;
  UInt8[0x00A0] oam;

  UInt8 curr_line_sprite_num;
  Oam[10] curr_line_sprites;
}

enum Mode {
  H_BLANK, /* To fill 456 Ticks in total since OAM Scan */
  V_BLANK, /* 10 scanlines of 456 Ticks */
  OAM_SCAN, /* 80 Ticks, checking every 2 */ /* <--- start here */
  DRAWING, /* Variable */
}

fn UInt8 Ppu.read(Ppu* ppu, UInt16 addr) {
  return ppu.vram[addr];
}

fn void Ppu.write(Ppu* ppu, UInt16 addr, UInt8 value) {
  ppu.vram[addr] = value;
}

fn UInt8 Ppu.oam_read(Ppu* ppu, UInt16 addr) {
  return ppu.oam[addr];
}

fn void Ppu.oam_write(Ppu* ppu, UInt16 addr, UInt8 value) {
  ppu.oam[addr] = value;
}

fn UInt8 Ppu.read_io(Ppu* ppu, UInt16 addr) {
  switch (addr) {
    case 0xFF40: return ppu.regs.lcdc;
    case 0xFF41: return ppu.regs.stat;
    case 0xFF42: return ppu.regs.scy;
    case 0xFF43: return ppu.regs.scx;
    case 0xFF44: return ppu.regs.ly; //0x90;
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

fn void Ppu.write_io(Ppu* ppu, UInt16 addr, UInt8 value) {
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
        UInt8 data = ppu.system.read(start_addr + i);
        ppu.system.write(0xFE00 + i, data);
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

fn UInt8 Ppu.remapBGColor(Ppu* ppu, UInt8 color) {
  switch(color) {
    case 0b00: return ppu.regs.bg_color00;
    case 0b01: return ppu.regs.bg_color01;
    case 0b10: return ppu.regs.bg_color10;
    case 0b11: return ppu.regs.bg_color11;
    default:
      io::printfn("Invalid pixel data %02x", color);
      return 0;
  }
}

fn UInt8 Ppu.remapSpriteColor(Ppu* ppu, UInt8 color, bool pallete2) {
  switch(color) {
    case 0b00: return pallete2 ? ppu.regs.obp1_color00 : ppu.regs.obp0_color00;
    case 0b01: return pallete2 ? ppu.regs.obp1_color01 : ppu.regs.obp0_color01;
    case 0b10: return pallete2 ? ppu.regs.obp1_color10 : ppu.regs.obp0_color10;
    case 0b11: return pallete2 ? ppu.regs.obp1_color11 : ppu.regs.obp0_color11;
    default:
      io::printfn("Invalid pixel data %02x", color);
      return 0;
  }
}

fn void Oam.print(Oam* oam) {
  io::printfn("Pos:(%02x %02x) Tile:%02x Flags:%02x", oam.x, oam.y, oam.tile, oam.flags);
}

fn void Ppu.loadSprites(Ppu* ppu) {
  UInt8 yPos = ppu.regs.ly;
  bool is_8_16 = ppu.regs.obj_size;
  UInt16 oam_addr = 0xFE00;

  for (UInt8 i = 0; i < 40; ++i) {
    Oam oam;
    oam.y = ppu.system.read(oam_addr + (i * 4)/*sizeof OAM*/ + 0);
    oam.x = ppu.system.read(oam_addr + (i * 4)/*sizeof OAM*/ + 1);
    oam.tile = ppu.system.read(oam_addr + (i * 4)/*sizeof OAM*/ + 2);
    oam.flags = ppu.system.read(oam_addr + (i * 4)/*sizeof OAM*/ + 3);

    if (oam.x == 0) continue;
    if (ppu.curr_line_sprite_num >= 10) break;
    if (oam.y <= yPos + 16 && (yPos + 16) < (oam.y + (is_8_16 ? 16 : 8))) {
      ppu.curr_line_sprites[ppu.curr_line_sprite_num] = oam;
      ppu.curr_line_sprite_num++;

      //io::printf("Found sprite (num %d) at %04x: ", ppu.curr_line_sprite_num, oam_addr + i * (8 * 4));
      //oam.print();
    }
  }
}

fn void Ppu.tick(Ppu* ppu, UInt64 tick) {
  UInt64 step = (tick + 1) % 457;

  if (ppu.regs.ly >= 144) {
    ppu.regs.mode_flag = 0b01;
  }
  else if (step < 80) {
    ppu.regs.mode_flag = 0b10;

    // Load sprites in the first tick, this is not real
    if (step == 0) {
      ppu.curr_line_sprite_num = 0;
      ppu.loadSprites();
      //io::printfn("Num sprites to render %d", ppu.curr_line_sprite_num);
    }
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

      UInt16 sprite_addr = 0x8000;

      UInt8 sx = ppu.regs.scx;
      UInt8 sy = ppu.regs.scy;
      UInt8 wx = ppu.regs.wx - 7;
      UInt8 wy = ppu.regs.wy;

      bool window = false;

      if (ppu.regs.window_display) {
        if (ppu.regs.ly >= wy) window = true;
      }

      bool unsig = true;
      UInt16 tileData = 0x8000;
      if (!ppu.regs.bg_window_tile_select) {
        unsig = false;
        tileData = 0x8800;
      }

      UInt16 backgroundMem = 0x9800;
      if (window) {
        if (ppu.regs.window_tile_map_select) {
          backgroundMem = 0x9c00;
        }
      }
      else {
        if(ppu.regs.bg_tile_map_select) {
          backgroundMem = 0x9c00;
        }
      }

      UInt8 yPos = sy + ppu.regs.ly;
      if (window) yPos = ppu.regs.ly - wy;

      UInt16 tileRow = ((UInt8)(yPos / 8)) * 32;
    
      for (UInt8 x = 0; x < 160; ++x) {
        UInt8 color = ppu.remapBGColor(0b00);

        if (ppu.regs.bg_window_show) {
          //ppu.system.lcd.framebuffer[ppu.regs.ly][x] = ppu.system.lcd.framebuffer[ppu.regs.ly][x] == 0 ? 1 : 0;
          UInt8 xPos = x + sx;
          if (window) {
            xPos = x - wx;
          }

          UInt16 tileCol = xPos / 8;
          Int16 tileNum;
          UInt16 tileAddress = backgroundMem + tileRow + tileCol;
          tileNum = (UInt8)ppu.system.read(tileAddress);
          if (!unsig) tileNum = (Int8)ppu.system.read(tileAddress);

          UInt16 tileLocation = tileData;
          if (unsig) { tileLocation += (tileNum * 16); }
          else { tileLocation += ((tileNum + 128) * 16); }
          //io::printfn("TileAddr %04x", tileLocation);

          UInt8 line = yPos % 8;
          line *= 2;
          UInt8 data1 = ppu.system.read((UInt16)(tileLocation + line));
          UInt8 data2 = ppu.system.read((UInt16)(tileLocation + line + 1));

          //io::printfn("Tile at %04x is %02x %02x", tileLocation + line, data1, data2);

          int colourBit = xPos % 8;
          colourBit -= 7;
          colourBit *= -1;

          UInt8 colourNum = ((data2 >> colourBit) & 0x1);
          colourNum <<= 1;
          colourNum |= ((data1 >> colourBit) & 0x1);

          //io::printfn("Color is %02x", colourNum);
          color = ppu.remapBGColor(colourNum);
        }

        if (ppu.regs.obj_show) {
          for (UInt8 i = 0; i < ppu.curr_line_sprite_num; ++i) {
            Oam oam = ppu.curr_line_sprites[i];
            UInt8 sp_x = oam.x - 8;
            if (x > (sp_x + 8)) continue;
            
            int offset = x - sp_x;
            if (offset < 0 || offset > 7) continue;
            
            UInt8 bit = (UInt8)((int)7 - offset);
            if (oam.xflip) bit = (UInt8)offset;
            
            int line = ppu.regs.ly - (oam.y - 16);
            if (oam.yflip) {
              line -= ppu.regs.obj_size ? 16 : 8;
              line *= -1;
              line -= 1;
            }
            UInt8 data1 = ppu.system.read((UInt16)(sprite_addr + oam.tile * 16 + line * 2));
            UInt8 data2 = ppu.system.read((UInt16)(sprite_addr + oam.tile * 16 + line * 2 + 1));            

            UInt8 colourNum = ((data2 >> bit) & 0x1);
            colourNum <<= 1;
            colourNum |= ((data1 >> bit) & 0x1);

            if (colourNum == 0b00) continue;

            if (!oam.priority || color == 0b00) {
              color = ppu.remapSpriteColor(colourNum, oam.pallette);
            }
          }
        }

        ppu.system.lcd.framebuffer[ppu.regs.ly][x] = color;
      }
      //ppu.system.lcd.redraw();
    }
    ppu.regs.ly = (ppu.regs.ly + 1) % 154;
    if (ppu.regs.ly == 144) {
      ppu.system.lcd.redraw();
      UInt8 interrupt = ppu.system.read(0xFF0F);
      interrupt = interrupt | (1 << 0); // VBLANK interrupt
      ppu.system.write(0xFF0F, interrupt);
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
        io::printf("%02x ", ppu.system.read((UInt16)(tileData + i)));
      } 
      io::printfn("");
      io::printfn("BackgroundMem 0x%04:", backgroundMem);
      for(int i = 0; i < 512; ++i) {
        io::printf("%02x ", ppu.system.read((UInt16)(backgroundMem + i)));
      } 
      io::printfn("");
      io::printfn("");
      */
    }
  }
}