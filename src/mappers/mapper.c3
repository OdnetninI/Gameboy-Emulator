module mappers;

import types;
import cart;

interface Mapper {
    fn void init();
    fn UInt32 calculateAddr(Cart* cart, UInt16 addr);
    fn UInt8 read(Cart* cart, UInt16 addr);
    fn void write(Cart* cart, UInt16 addr, UInt8 value);
    fn UInt8 ram_read(Cart* cart, UInt16 addr);
    fn void ram_write(Cart* cart, UInt16 addr, UInt8 value);
}