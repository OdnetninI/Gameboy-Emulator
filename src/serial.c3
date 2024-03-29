module serial;

import std::io;

import types;
import system;

struct Serial {
  System* system;
  UInt8 sb;
  bitstruct : UInt8 @overlap {
    UInt8 sc : 0..7;
    bool transfer_start : 7;
    bool clock_speed : 1;
    bool internal_clock : 0;
  }
  UInt8 step;

  // Network
  bool disconected;
  bool master;
  String port;
}

fn void Serial.init(Serial* serial, System* system) {
  serial.system = system;
  serial.sb = 0x00;
  serial.sc = 0x00;
  serial.step = 0x00;
}

fn UInt8 Serial.read(Serial* serial, UInt16 addr) {
  switch(addr) {
    case 0xff01: if (serial.disconected) return 0xff; return serial.sb;
    case 0xff02: return serial.sc;
  }
  return 0xff;
}

fn void Serial.write(Serial* serial, UInt16 addr, UInt8 value) {
  switch(addr) {
    case 0xff01: serial.sb = value;
    case 0xff02: serial.sc = value;
  }
}

fn void Serial.tick(Serial* serial, UInt64 tick_counter) {
  if (tick_counter % 16 != 0) return;

  if (serial.transfer_start) {
    if (!serial.disconected) {
      UInt8[1] byte;
      byte[0] = serial.sb;
      serial.sb = 0xff;
      serial.transfer_start = false;
      UInt8 _if = serial.system.read(0xFF0F);
      _if = _if | (1 << 3);
      serial.system.write(0xFF0F, _if);
    }
  }
  else {
    if (serial.disconected) return;
    UInt8[1] byte;
    usz! bytes_read = 0x00;
    if (try usz bytes = bytes_read) {
      if (bytes > 0) {
        if (byte[0] == 'S') {
          bytes_read = 0x00;
          serial.transfer_start = true;
          if (try usz _bytes = bytes_read) {
            if (_bytes > 0) {
            serial.sb = byte[0];
            serial.transfer_start = false;
            //io::printfn("Received: %c", serial.sb);
            UInt8 _if = serial.system.read(0xFF0F);
            _if = _if | (1 << 3);
            serial.system.write(0xFF0F, _if);
            }
          }
        }
      }
    }
  }
}
