#!/usr/bin/env python

import rpm

import rpmUtils


#ts = rpm.TransactionSet()
mi = ts.dbMatch()
for h in mi:
    print "%s-%s-%s" % (h['name'], h['version'], h['release'])