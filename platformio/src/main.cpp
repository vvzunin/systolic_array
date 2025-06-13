#include <Arduino.h>
#include <HardwareSerial.h>

#define BAUDRARE 9600
HardwareSerial SerialFPGA(2);

void transferByte(Stream& from, Stream& to);

void setup() {
  Serial.begin(BAUDRARE);
  SerialFPGA.begin(BAUDRARE);
}

void loop() {
  while(SerialFPGA.available())
    transferByte(SerialFPGA, Serial);
  
  while(Serial.available())
    transferByte(Serial, SerialFPGA);
}

void transferByte(Stream &from, Stream &to)
{
  uint8_t buf;
  size_t bytes = from.readBytes(&buf, 1);
  if(bytes != 0) to.write(buf);
}
