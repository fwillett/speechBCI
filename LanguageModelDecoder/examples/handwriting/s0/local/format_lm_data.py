import argparse
import json
import re

parser = argparse.ArgumentParser(description='Format LM data')
parser.add_argument('--input_text', type=str, required=True)
parser.add_argument('--output_text', type=str, required=True)
parser.add_argument('--dict', type=str, required=True)
parser.add_argument('--with_punctuation', action='store_true')
parser.add_argument('--with_space_symbol', action='store_true')
parser.add_argument('--unk', action='store_true')
args = parser.parse_args()

# Read the dictionary
lexicons = set()
with open(args.dict, 'r') as f:
    for line in f.readlines():
        tokens = line.strip().split(' ')
        lexicons.add(tokens[0].lower())

# Preprocess texts and write to output
output = open(args.output_text, 'w')
input = open(args.input_text, 'r')
count = 0
while True:
    line = input.readline()
    if not line:
        break
    count += 1

    if count % 10000 == 0:
        print(count)

    modifiedText = line.strip().replace('\n',' ')
    modifiedText = modifiedText.replace('-',' ')
    modifiedText = re.sub("[^a-z .',?]", '', modifiedText.lower())
    modifiedText = re.sub(' +', ' ', modifiedText)
    modifiedText = modifiedText.replace(' .','.')
    modifiedText = modifiedText.replace(' ,',',')
    modifiedText = modifiedText.replace(', ',',')
    modifiedText = modifiedText.replace('..','.')
    modifiedText = modifiedText.strip()

    #split into sentences
    modifiedText = modifiedText.replace('.','.\n')
    modifiedText = modifiedText.replace('. ','.\n')
    modifiedText = modifiedText.replace('?','?\n')
    modifiedText = modifiedText.replace('? ','?\n')

    allNewLines = modifiedText.split('\n')

    for x in range(len(allNewLines)):
        if len(allNewLines[x]) > 4:
            newLine = allNewLines[x].strip()
            if args.with_space_symbol:
                newLine = newLine.replace(' ',' > ')

            if args.with_punctuation:
                newLine = newLine.replace('.',' .')
                newLine = newLine.replace(',',' , ')
                newLine = newLine.replace('?',' ?')
            else:
                newLine = newLine.replace('.','')
                newLine = newLine.replace(',','')
                newLine = newLine.replace('?','')

            hasAllWords = True
            if not args.unk:
                words = newLine.split(' ')
                for w in words:
                    if not w in lexicons:
                        hasAllWords = False
                        break

            if hasAllWords:
                output.write(newLine.upper()+'\n')

output.close()
input.close()