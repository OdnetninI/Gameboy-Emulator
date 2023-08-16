module lcd;

import types;

import std::io;
import raylib;

struct Lcd {
  raylib::RenderTexture2D target;
  UInt8[160][144] framebuffer;
}

fn void Lcd.init(Lcd* lcd) {
  raylib::init_window(160 * 2, 144 * 2, "GB");
  
  raylib::set_target_fps(60);

  lcd.target = raylib::load_render_texture(160 * 2, 144 * 2);

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
}

fn void Lcd.redraw(Lcd* lcd) {
  raylib::begin_texture_mode(lcd.target);
    raylib::clear_background(raylib::RAYWHITE);
    for(UInt8 y = 0; y < 144; ++y) {
      for (UInt8 x = 0; x < 160; ++x) {
        raylib::Color color;
        switch(lcd.framebuffer[143-y][x]) {
          case 0: color = raylib::RAYWHITE;
          case 1: color = raylib::LIGHTGRAY;
          case 2: color = raylib::DARKGRAY;
          case 3: color = raylib::BLACK;
          case 4: color = raylib::YELLOW;
          case 5: color = raylib::PINK;
          default: color = raylib::RED;
        }
        raylib::draw_pixel(x * 2, y * 2, color);
        raylib::draw_pixel(x * 2 + 1, y * 2, color);
        raylib::draw_pixel(x * 2, y * 2 + 1, color);
        raylib::draw_pixel(x * 2 + 1, y * 2 + 1, color);
      }
    }
  raylib::end_texture_mode();

  raylib::begin_drawing();
    raylib::clear_background(raylib::MAGENTA);
    raylib::draw_texture(lcd.target.texture, 0, 0, raylib::RAYWHITE);
  raylib::end_drawing();
}

fn void Lcd.update(Lcd* lcd) {
  
}

fn void Lcd.close(Lcd* lcd) {
  raylib::unload_render_texture(lcd.target);
  raylib::close_window();
}