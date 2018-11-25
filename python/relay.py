import threading
import serial

ser1 = serial.Serial('/dev/ttyXRUSB1',2400)

ser0 = serial.Serial('/dev/ttyXRUSB0',2400)

def checkSer0():
    while(True):
        val1 = ser1.read()
        print(val1)
        ser0.write(val1)


def checkSer1():
    while(True):
        val0 = ser0.read()
        print(val0)
        ser1.write(val0)


port0 = threading.Thread(target=checkSer0)
port1 = threading.Thread(target=checkSer1)

port0.start()
port1.start()

while(True):
    pass
