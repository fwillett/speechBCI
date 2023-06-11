import redis
import sys
import numpy as np
import time

print("starting Redis connection")
r = redis.Redis(host='localhost', port=6379, db=0)

print("running...")

ctc_logits = np.load('/home/cfan/logits.npy')
print(f'logits shape {ctc_logits.shape}')


r.xadd('binned:decoderOutput:stream', {'start': ''})

for t in range(ctc_logits.shape[0]):
  r.xadd('binned:decoderOutput:stream', {'data': ctc_logits[t].tobytes(order='C')})
  time.sleep(0.01)

r.xadd('binned:decoderOutput:stream', {'end': ''})

r.close()
