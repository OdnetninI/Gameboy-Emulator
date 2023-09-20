module lcd;

import types;

import std::io;
import raylib;

struct Lcd {
  UInt8[160][144] framebuffer;
  UInt8[160*144*4] pixels;
  raylib::Image img;
  raylib::Texture tex;
}

UInt8 zoom = 3;

fn void Lcd.init(Lcd* lcd) {
  raylib::init_window(160 * zoom, 144 * zoom, "GB");
  
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

  raylib::begin_drawing();
    raylib::clear_background(raylib::MAGENTA);
    //raylib::draw_texture(lcd.tex, 0, 0, raylib::RAYWHITE);
    raylib::draw_texture_pro(lcd.tex, 
      {0, 0, 160, 144}, 
      {0, 0, (float)(160 * zoom), (float)(144 * zoom)},
      {0, 0},
      0.0f, raylib::RAYWHITE);
  raylib::end_drawing();
}

fn void Lcd.update(Lcd* lcd) {
  
}

fn void Lcd.close(Lcd* lcd) {
  //raylib::unload_render_texture(lcd.target);
  raylib::close_window();
}