import os
import sys

assert len(sys.argv) == 3
lexicon_in = sys.argv[1]
lexicon_out = sys.argv[2]

phones_with_stress = {'AA', 'AE', 'AH', 'AO', 'AW', \
                      'AY', 'EH', 'ER', 'EY', 'IH', 'IY', \
                      'OW', 'OY', 'UH', 'UW'
                     }

out_f = open(lexicon_out, 'w')
with open(lexicon_in, 'r', encoding='utf-8', errors='ignore') as in_f:
  lines = in_f.readlines()
  for i, line in enumerate(lines):
    if line.startswith(';;;'):
      continue
    line = line.strip()
    if '\t' in line:
      lexicon, phones = line.split('\t')
      phones = phones.strip().split(' ')
    else:
      tokens = line.split(' ')
      lexicon = tokens[0]
      phones = []
      for t in tokens[1:]:
        if len(t) > 0:
          phones.append(t)
    new_phones = []
    for p in phones:
      if p[:-1] in phones_with_stress:
        new_phones.append(p[:-1])
      else:
        new_phones.append(p)
    #print(new_phones, " ".join(new_phones))
    out_f.write(f'{lexicon}\t{" ".join(new_phones)}\n')
out_f.close()