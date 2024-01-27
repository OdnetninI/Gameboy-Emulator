module lcd;

import types;

import std::io;
import raylib;

import system;

struct Lcd {
  System* system;
  UInt8[160][144] framebuffer;
  UInt8[160*144*4] pixels;
  raylib::Image img;
  raylib::Texture tex;
}

UInt8 zoom = 3;

fn void Lcd.init(Lcd* lcd, System* system) {
  lcd.system = system;

  raylib::init_window((160 * zoom) + 160, 144 * zoom, "GB");
  
  raylib::set_target_fps(60);

  lcd.img = raylib::gen_image_color(160, 144, raylib::RED);
  raylib::image_format(&lcd.img, UNCOMPRESSED_R8G8B8A8);
  lcd.tex = raylib::load_texture_from_image(lcd.img);

  for(UInt8 y = 0; y < 144; ++y) {
    for (UInt8 x = 0; x < 160; ++x) {
      /*if (y == x) { lcd.framebuffer[143-y][x] = 5; }
      else if (y == 0) { lcd.framebuffer[143-y][x] = 1; }
      else if (x == 0) { lcd.framebuffer[143-y][x] = 2; }
      else if (x == 159) { lcd.framebuffer[143-y][x] = 3; }
      else if (y == 143) { lcd.framebuffer[143-y][x] = 4; }
      else { lcd.framebuffer[143-y][x] = 0; }*/
      lcd.framebuffer[y][x] = 0;
    }
  }

  lcd.redraw();
}

fn void Lcd.redraw(Lcd* lcd) {
  for(UInt8 y = 0; y < 144; ++y) {
    for (UInt8 x = 0; x < 160; ++x) {
      raylib::Color color;
      switch(lcd.framebuffer[y][x]) {
        case 0: color = raylib::RAYWHITE;
        case 1: color = raylib::LIGHTGRAY;
        case 2: color = raylib::DARKGRAY;
        case 3: color = raylib::BLACK;
        case 4: color = raylib::YELLOW;
        case 5: color = raylib::PINK;
        default: color = raylib::RED;
      }
      //raylib::draw_pixel(x, y, color);
      lcd.pixels[(x + y * 160) * 4 + 0] = color.r;
      lcd.pixels[(x + y * 160) * 4 + 1] = color.g;
      lcd.pixels[(x + y * 160) * 4 + 2] = color.b;
      lcd.pixels[(x + y * 160) * 4 + 3] = 0xff;
    }
  }
  raylib::update_texture(lcd.tex, &lcd.pixels);

  lcd.draw_panel();
}

fn void Lcd.draw_panel(Lcd* lcd) {
  raylib::begin_drawing();
    raylib::clear_background(raylib::LIGHTGRAY);
    //raylib::draw_texture(lcd.tex, 0, 0, raylib::RAYWHITE);
    raylib::draw_texture_pro(lcd.tex, 
      {0, 0, 160, 144}, 
      {0, 0, (float)(160 * zoom), (float)(144 * zoom)},
      {0, 0},
      0.0f, raylib::RAYWHITE);

    raylib::draw_text(raylib::text_format("AF: %04X\n", lcd.system.cpu.regs.af), 160 * zoom + 2, 2, 20, raylib::BLACK);
    raylib::draw_text(raylib::text_format("BC: %04X\n", lcd.system.cpu.regs.bc), 160 * zoom + 2, 22, 20, raylib::BLACK);
    raylib::draw_text(raylib::text_format("DE: %04X\n", lcd.system.cpu.regs.de), 160 * zoom + 2, 42, 20, raylib::BLACK);
    raylib::draw_text(raylib::text_format("HL: %04X\n", lcd.system.cpu.regs.hl), 160 * zoom + 2, 62, 20, raylib::BLACK);
    raylib::draw_text(raylib::text_format("PC: %04X\n", lcd.system.cpu.regs.pc), 160 * zoom + 2, 82, 20, raylib::BLACK);
    raylib::draw_text(raylib::text_format("SP: %04X\n", lcd.system.cpu.regs.sp), 160 * zoom + 2, 102, 20, raylib::BLACK);
    if (lcd.system.cart.mapper) {
      UInt32 addr = lcd.system.cart.calculateAddr(lcd.system.cpu.regs.pc);
      raylib::draw_text(raylib::text_format("CART: %02X:%04X\n", (addr >> 16) & 0xFF, addr & 0xFFFF), 160 * zoom + 2, 122, 20, raylib::BLACK);
    }
  raylib::end_drawing();
}

fn void Lcd.update(Lcd* lcd) {
  
}

fn void Lcd.close(Lcd* lcd) {
  //raylib::unload_render_texture(lcd.target);
  raylib::close_window();
}
