import fl
import time
import binascii

key = 0x12345678

def bitlist2num(lst):
    out = 0
    for bit in lst:
        out = (out << 1) | bit
    return out

def concat(num,times):
    out = num
    for i in range(times-1):
        out = out << 4 | out
    return out

def encrypt(p):
    n1 = str(bin(key)).count('1')
    t = [0]*4
    for i in range(8):
        t[3] = t[3] ^ ( (key & (1 << ( 4*i ))) >> ( 4*i ) )
        t[2] = t[2] ^ ( (key & (1 << (4*i+1))) >> (4*i+1) )
        t[1] = t[1] ^ ( (key & (1 << (4*i+2))) >> (4*i+2) )
        t[0] = t[0] ^ ( (key & (1 << (4*i+3))) >> (4*i+3) )
    t = bitlist2num(t)
    c = p
    for i in range(n1) : 
        c = c ^ concat(t,8)
        t = t+1
        if t == 16 :
            t = t-16
    return c

def decrypt(c):
    n0 = 32 - str(bin(key)).count('1')
    t = [0]*4
    for i in range(8):
        t[3] = t[3] ^ ( (key & (1 << ( 4*i ))) >> ( 4*i ) )
        t[2] = t[2] ^ ( (key & (1 << (4*i+1))) >> (4*i+1) )
        t[1] = t[1] ^ ( (key & (1 << (4*i+2))) >> (4*i+2) )
        t[0] = t[0] ^ ( (key & (1 << (4*i+3))) >> (4*i+3) )
    t = bitlist2num(t) - 1
    if t < 0: 
        t = 15
    p = c
    for i in range(n0) : 
        p = p ^ concat(t,8)
        t = t-1
        if t < 0:
            t = 15
    return p

def read_bytes_and_decrypt(handle,channel,to):

    byte_buffer = [None]*4
    byte_count = 0
    current_time = time.time()
    time_out = False
    not_zero_det = False

    while not not_zero_det:
        if time.time() - current_time > to :
            time_out = True
            break
        else :
            num = fl.flReadChannel(handle,channel,1)
            fl.flSleep(50)
            if not num == 0 : 
                byte_buffer[byte_count] = num
                byte_count += 1 
                while byte_count < 4:
                    num = fl.flReadChannel(handle,channel,1)
                    byte_buffer[byte_count] = num
                    fl.flSleep(50)
                    byte_count+=1
                not_zero_det = True

    if not time_out : 
        byte_buffer.reverse()
        c = 0
        for read_byte in byte_buffer:
            c = c << 8 | read_byte
        p = decrypt(c)
        return p
    else :
        return False

def encrypt_and_write_bytes(handle,channel,numBytes,data):
    send = []
    p = encrypt(data)
    for i in range(numBytes) :
        eight_bits = p & 0xff
        send.append(eight_bits)
        p = p >> 8
    
    for num in send:
        fl.flWriteChannel(handle,channel,num)
        fl.flSleep(50)
