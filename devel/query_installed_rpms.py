#!/usr/bin/env python

import os, sys, types, string, re

try:
    import zypp
except ImportError:
    print 'Dummy Import Error: Unable to import zypp bindings'

#Beispielcode

Z = zypp.ZYppFactory_instance().getZYpp()
Z.initializeTarget( zypp.Pathname("/") )
Z.target().load();

for item in Z.pool().byNameIterator():
    print item
#myRepoInfo = zypp.RepoInfo()
#
# for item in Z.pool():
#     # if not item.status().isInstalled():
#     #     continue
#
#     #if item.name() == "dfs_remotePiloten_appHandling":
#     #if item.name() == "zlib-devel":
#     if item.name() == "python-xlib":
#         print "FOUND:%s-%s.%s.rpm" % (
#             item.name(),
#             item.edition(),
#             item.arch()
#         )

# zlib-devel-1.2.3-106.34.i586.rpm
    # else:
    #     print "%s:%s-%s.%s" % ( item.kind(),
    #     item.name(),
    #     item.edition(),
    #     item.arch(),
    #     )
#        item.repoInfo().alias()
    # if zypp.isKindPackage( item ):
    #     print " Group: %s" %(zypp.asKindPackage( item ).group( ) )



# for rpm in ["dfs_remotePiloten_appHandling","gnome-desktop","tcpdump"]:
#     if
#     print "%s" % (rpm,)

# for item in Z.pool():
#     print item.name()

# if zypp.isKindPackage(item):
# msg += "Name: "
# msg += str(item.name())
# msg += " - "
# msg += "Version: "
# msg += str(zypp.asKindPackage(item).edition())
# msg += " - "
# msg += "Summary: "
# msg += str(zypp.asKindPackage(item).summary())
# msg += "\n"
# lowerLog.appendLines(str(msg))
#


