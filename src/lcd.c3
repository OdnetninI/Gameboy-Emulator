module lcd;

import types;

import raylib;

struct Lcd {
  int a;
}

fn void Lcd.init(Lcd* lcd) {
  raylib::init_window(160, 144, "GB");
  defer raylib::close_window();
  
  raylib::set_target_fps(60);

  while(!raylib::window_should_close()) {
    raylib::begin_drawing();
    raylib::clear_background(raylib::RAYWHITE);
    raylib::draw_text("Congrats! You created your first window!", 190, 200, 20, raylib::LIGHTGRAY);
    raylib::end_drawing();
  }
}