module apu::lengthduty;

import types;

Int16[8][4] duty = {
    {-1, -1, -1, -1, -1, -1, -1, 1},
    {1, -1, -1, -1, -1, -1, -1, 1},
    {1, -1, -1, -1, -1, 1, 1, 1},
    {-1, 1, 1, 1, 1, 1, 1, -1}
};

struct LengthDuty {
  UInt8 duty;
  UInt8 length;
  Int16[8] dutyTable;
}

fn void LengthDuty.init(&lengthduty) {
  lengthduty.duty = 0;
  lengthduty.length = 0;
  lengthduty.dutyTable = duty[0];
}

fn UInt8 LengthDuty.read(&lengthduty) {
  return lengthduty.duty | 0x3f;
}

fn void LengthDuty.write(&lengthduty, UInt8 value) {
  lengthduty.length = 64 - (value & 0x3f);
  lengthduty.duty = value & 0xc0;
  lengthduty.dutyTable = duty[value >> 6];
}

fn void LengthDuty.tick(&lengthduty, bool* enabled) {
  if (lengthduty.length > 0) {
    lengthduty.length -= 1;
  }
  if (lengthduty.length == 0) {
    *enabled = false;
  }
}
