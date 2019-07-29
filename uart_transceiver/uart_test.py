import numpy as np
import serial
import time

# Serial Port Initialization
ser = serial.Serial()
ser.baudrate = 115200
ser.port = 'COM5'
ser.timeout = 0.1
ser.open()

while True:
   try:
       data_to_send = input('Enter a number from 0 to 255: ')
       data_to_send = int(data_to_send)
       if data_to_send >= 0 and data_to_send <= 255:
           data_byte = (data_to_send).to_bytes(1, byteorder="little")
           ser.write(data_byte)
           echo = ser.read(1)
           # print(echo)
           print(int.from_bytes(echo, byteorder="big"))
           time.sleep(0.1)
   except KeyboardInterrupt:
       break
