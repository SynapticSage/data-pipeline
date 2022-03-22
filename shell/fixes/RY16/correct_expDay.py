#!/usr/bin/env python2
'''
File used to correct expDay numbers in local and server
directories.
'''

import os
import sys
import glob
import shutil as sh
import atexit


if len(sys.argv) > 1:
    final = int(sys.argv[1])
else:
    raise ValueError("Must provide new starting day")

if len(sys.argv) > 2:
    initial = int(sys.argv[2])
else:
    raise ValueError("Must provide old starting day")

if len(sys.argv) > 3:
    folder = sys.argv[3]
else:
    folder = os.getcwd()

if len(sys.argv) > 4:
        doMove = int(sys.argv[4])
else:
        doMove = 0


correction = -(final - initial)
print('Initial: {initial}, Final: {final}, Folder:{folder}')

pwd = os.getcwd()
atexit.register(lambda : os.chdir(pwd)) # if exit, return to folder
os.chdir(folder)

def apply_correction(f):
    f = f.split('expDay')
    component_without = f[0]
    component_with    = f[1]

    contains_underscore = False
    if '.' in component_with:
        dot_location = component_with.find('.')
        number = component_with[:dot_location]
        if '_' in number:
            parts = number.split("_")
            number = int(parts[0])
            contains_underscore = True
        else:
            number = int(number)
    else:
        number = int(component_with)


    form = lambda N : "{:02d}".format(N)
    if contains_underscore:

        parts.pop(0)
        number  = form(number+correction)
        tup = [number] + parts
        number = "_".join(tup)
    else:
        number += correction
        number = form(number)

    # Construct a new file string
    if '.' in component_with:
        newFile = 'expDay'.join((component_without, number + component_with[dot_location:]))
    else:
        newFile = 'expDay'.join(component_without, number + component_with[dot_location:])
    return newFile

# -------------------
# Overarching folders
# -------------------
folders = glob.glob('./**/*expDay*')

for old_file in folders:

    # Rip up the old file string and get the number
    newFile = apply_correction(old_file)
    print(old_file, newFile)
    if doMove > 0 or doMove == -1:
        sh.move(old_file, newFile)

# -------------------
# Rename dat-files
# -------------------
files = glob.glob('./**/**/*expDay*')
for old_file in files:

    dirname  = os.path.dirname(old_file)
    basename = os.path.basename(old_file)

    new_file = apply_correction(basename)
    new_file = os.path.join(dirname, new_file)
    print(old_file, new_file)
    if doMove > 0:
        try:
            sh.move(old_file, new_file)
        except Exception:
            import pdb
            pdb.set_trace()
