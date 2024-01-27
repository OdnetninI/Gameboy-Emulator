module apu::envelope;

import types;

struct Envelope {
  UInt8 volume;
  UInt8 volume_init;
  UInt8 add;
  UInt8 period;
  UInt8 timer;
}

fn void Envelope.init(&envelope) {
  envelope.volume = 0;
  envelope.volume_init = 0;
  envelope.add = 0;
  envelope.period = 0;
  envelope.timer = 0;
}

fn UInt8 Envelope.read(&envelope) {
  return (envelope.volume_init << 4) | envelope.add | envelope.period;
}

fn void Envelope.write(&envelope, UInt8 value) {
  envelope.add = value & 0x08;
  envelope.period = value & 0x07;
  envelope.add = value & 0x07;
  envelope.volume_init = (value >> 4) & 0x0f;
  envelope.volume = envelope.volume_init;
}

fn void Envelope.tick(&envelope) {
  if (envelope.period > 0) {
    if (envelope.timer > 0) {
      envelope.timer -= 1;
    }
    else {
      if (envelope.add != 0) {
        if (envelope.volume < 0x0f) envelope.volume += 1;
      }
      else {
        if (envelope.volume > 0x00) envelope.volume += 1;
      }

      envelope.timer = envelope.period;
    }
  }
}
