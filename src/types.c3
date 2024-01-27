module types;

def Int8 = ichar;
def UInt8 = char;
def Int16 = short;
def UInt16 = ushort;
def Int32 = int;
def UInt32 = uint;
def UInt64 = ulong;

def Register = UInt8;
def Register16 = UInt16;

def Addr = UInt16;

bitstruct Mem16 : UInt16 @overlap {
  Register16 value : 0..15;
  Register high : 8..15;
  Register low : 0..7;
}