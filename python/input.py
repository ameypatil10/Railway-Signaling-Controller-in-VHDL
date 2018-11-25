import fl
vp = "1D50:602B:0002"
handle = fl.FLHandle()
fl.flInitialise(0)
handle = fl.flOpen(vp)
fl.flSelectConduit(handle, 1)