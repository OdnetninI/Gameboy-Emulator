module ppu;

import types;

struct Ppu {
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
  UInt8 bgp;
  UInt8 obp0;
  UInt8 obp1;
  UInt8 wy;
  UInt8 wx;
}

fn UInt8 Ppu.read(Ppu* ppu, UInt16 addr) {
  return 0;
}

fn void Ppu.write(Ppu* ppu, UInt16 addr, UInt8 value) {
  return;
}