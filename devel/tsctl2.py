#!/usr/bin/env python
#
# Peter Krauspe (c) 7/2015
#
# 2step control web application server control script 1.0 :-))
# Python version
#

from sys import argv
from os import path
import socket

port = 65003

# netcat in python

def netcat(hostname, port, content):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((hostname, port))
    s.sendall(content)
    s.shutdown(socket.SHUT_WR)
    while 1:
        data = s.recv(1024)
        if data == "":
            break
        #print repr(data)
        print data
    s.close()


#  main

if len(argv) < 2 :
    print "\nusage: " + path.basename(argv[0]) + " <hostname> <command>\n"
else:
    host = argv[1]
    try:
        QSTRING = argv[2]
    except IndexError:
        QSTRING = 'help'

    netcat(host, port, QSTRING)


