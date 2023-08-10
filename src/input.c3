module input;

import std::io;

import system;
import raylib;

import types;

bitstruct Joypad : UInt8 @overlap {
  UInt8 data : 0..7;
  bool action : 5;
  bool direction : 4;
  bool down_start : 3;
  bool up_select : 2;
  bool left_b : 1;
  bool right_a : 0;
}

fn void updateKeys(System* system) {
  Joypad joypad;
  joypad.data = system.mem.read(0xFF00);

  joypad.right_a = true;
  joypad.left_b = true;
  joypad.down_start = true;
  joypad.up_select = true;

  if (!joypad.direction) {
    if(raylib::is_key_down(raylib::keyboard::RIGHT)) joypad.right_a = false;  
    if(raylib::is_key_down(raylib::keyboard::LEFT)) joypad.left_b = false;  
    if(raylib::is_key_down(raylib::keyboard::DOWN)) joypad.down_start = false;  
    if(raylib::is_key_down(raylib::keyboard::UP)) joypad.up_select = false;  
  }
  else if (!joypad.action) {
    if(raylib::is_key_down(raylib::keyboard::Z)) joypad.right_a = false;  
    if(raylib::is_key_down(raylib::keyboard::X)) joypad.left_b = false;  
    if(raylib::is_key_down(raylib::keyboard::ENTER)) joypad.down_start = false;  
    if(raylib::is_key_down(raylib::keyboard::BACKSPACE)) joypad.up_select = false; 
  }

  system.mem.write(0xFF00, joypad.data);
}