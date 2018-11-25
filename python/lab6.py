import fl
import serial
import railway_functions as rf
import signal
from tempfile import mkstemp
from shutil import move
from os import fdopen,remove
import sys

ack1 = 0xb000000b
ack2 = 0xdeaf7654
vp = "1D50:602B:0002"

x = None
y = None
ch_ind = None

# H1
file_data = []
f = None
def update_data() :
    global f, file_data
    try: 
        f = open('network.txt', 'r+')
    except FileNotFoundError:
        print("File couldn't be located in this directory ...")

    if f :
        file_data = []
        for line in f:
            try:
                file_data.append([int(i) for i in line.split(",")])
            except ValueError:
                pass

        f.close()

def ch2(handle) :
    global x,y,ch_ind
    while True:
        msg_i = rf.read_bytes_and_decrypt(handle,2*ch_ind,3)
        rf.encrypt_and_write_bytes(handle,2*ch_ind+1,4,msg_i)
        received_ack = rf.read_bytes_and_decrypt(handle,2*ch_ind,3)
        if received_ack == ack1 :
            # Genuine controller at this index
            print("Genuine controller at channel " + hex(2*ch_ind))
            break

def h2(handle) :
    global x,y,ch_ind

    def set_channel_and_coordinates(coord,ch):
        global x,y,ch_ind
        ch_ind = ch
        coord = ( coord >> 24 ) & 0xff
        x = coord >> 4
        y = coord & 0x0f

    for i in range(0,64):
        if (not ch_ind == None) and (not ch_ind == i):
            continue
        msg_i = rf.read_bytes_and_decrypt(handle,2*i,3)
        rf.encrypt_and_write_bytes(handle,2*i+1,4,msg_i)
        received_ack = rf.read_bytes_and_decrypt(handle,2*i,3)
        if received_ack == ack1 :
            # Genuine controller at this index
            print("Genuine controller at channel " + hex(2*i))
            set_channel_and_coordinates(msg_i,i)
            break
        else :
            print("Didn't get ack on channel " + hex(2*i))
            print("Waiting for 5 seconds and retrying ...")
            fl.flSleep(5000)
            received_ack = rf.read_bytes_and_decrypt(handle,2*i,5)
            if received_ack == ack1:
                print("Genuine controller at channel " + hex(2*i))
                set_channel_and_coordinates(msg_i,i)
                break
            else :
                print("No controller here. Continuing ...")
                continue

def h4() :
    global x,y,ch_ind,file_data
    filter_fn = lambda item : item[0] == x and item[1] == y
    filter_by_coordinates = list(filter(filter_fn,file_data))
    track_info = {}
    for data in filter_by_coordinates:
        # Order DIR|TE|TOK|NUM
        track_info[data[2]] = (data[2] << 5) + (1 << 4) + (data[3] << 3) + data[4]
    track_data = []
    for i in range(8):
        if i in track_info:
            track_data.append(track_info[i])
        else :
            track_data.append(i)
    track_data.reverse()
    last_four = 0
    for num in track_data[0:4]:
        last_four = (last_four << 8) | num
    first_four = 0
    for num in track_data[4:8]:
        first_four = (first_four << 8) | num
    return (first_four,last_four) 

def update_file(signal, frame) :
    global file_data
    print("updating network.txt ...\n")
    fh, abs_path = mkstemp()
    with fdopen(fh,"w+") as new_file :
        for entry in file_data :
            new_file.write(str(entry)[1:-1] + "\n")

    remove('network.txt')
    move(abs_path,'network.txt')
    sys.exit(0)

signal.signal(signal.SIGINT, update_file)
handle = fl.FLHandle()

try: 
    fl.flInitialise(0)
    print("Attempting to open connection to the board ...")
    try:
        handle = fl.flOpen(vp)
    except fl.FLException :
        print("flOpen Error (line 39)")
    
    fl.flSelectConduit(handle,1)
    if fl.flIsCommCapable(handle,1):
        update_data()
        i = 0
        while True :
            # H2 : Polling to be done only on the
            # first try.
            if i == 0:
                h2(handle)
            else:
                ch2(handle)
            i = i +1
            # H3
            print("H3")
            rf.encrypt_and_write_bytes(handle,2*ch_ind + 1,4,ack2)
            # H4
            print("H4")
            (first_four,last_four) = h4()
            # H5
            print("H5")
            rf.encrypt_and_write_bytes(handle,2*ch_ind+1,4,first_four)
            is_successful = False
            for t in range(256):
                #H6
                print("H6")
                received_ack = rf.read_bytes_and_decrypt(handle,2*ch_ind,3)
                if received_ack == ack1:
                    second_successful = False
                    for t1 in range(256):
                        #H7
                        print("H7")
                        rf.encrypt_and_write_bytes(handle,2*ch_ind+1,4,last_four)
                        second_ack = rf.read_bytes_and_decrypt(handle,2*ch_ind,3)
                        if second_ack == ack1:
                            second_successful = True
                            rf.encrypt_and_write_bytes(handle,2*ch_ind+1,4,ack2)
                            break
                    if second_successful :
                        is_successful = True
                        break

            if is_successful :
                fpga = serial.Serial(port="/dev/ttyXRUSB0",baudrate=2400,timeout=10)
                print ("Window to read from FPGA started")
                new_track_data = rf.read_bytes_and_decrypt(handle,2*ch_ind,36)
                print("Window has ended")
                print("New Track Data: ", new_track_data)
                if type(new_track_data) == int:
                    direc = (new_track_data & 0xe0) >> 5
                    for entry in file_data : 
                        # Order DIR|TE|TOK|NUM
                        if entry[0] == x and entry[1] == y and entry[2] == direc:
                            entry[3] = ( new_track_data & 0x8 ) >> 3
                            entry[4] = ( new_track_data & 0x7 )
                        print(file_data)
                
                # At this point we are checking whether we are 
                # getting uart data from the neighbouring 
                # controller
                #received_byte = fpga.read()
                #print(received_byte)
                print(fpga.write(b'\x00'))
                #fl.flSleep(20000)
                rf.read_bytes_and_decrypt(handle,4,1)
        fl.flClose(handle)
    else :
        print("Not CommCapable")

except fl.FLException :
    print("flInitialisation Error")
finally:
    fl.flClose(handle)
