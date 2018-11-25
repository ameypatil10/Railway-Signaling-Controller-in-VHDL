import fl
fl.flInitialise(0)

handle = fl.flOpen("1D50:602B:0002")
fl.flSelectConduit(handle,1)

def read(a,b):
    return fl.flReadChannel(handle,a,b)
def write(a,b):
    fl.flWriteChannel(handle,a,b)

def aread(a,b):
    fl.flReadChannelAsyncSubmit(handle,a,b)
    return fl.flReadChannelAsyncAwait(handle)
def awrite(a,b):
    fl.flWriteChannel(handle,a,b)

