#!/usr/bin/ksh
#
# (c) Peter Krauspe 10/2015
#
# This script should run on once on any resource nss 
# It copys a special version of xinitrc which changes the background of resource nsc's depending on it's configuration
#
#
# <2step>
. /etc/2step/2step.vars
#
dbg=echo
dbg=""
dev=eth0
# ggfs spaeter aus config file
basedir=/opt/dfs/tsctl2
bindir=${basedir}/bin
confdir=${basedir}/config
vardir=${basedir}/var
source ${confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers

nsc_sh "[ -f /etc/X11/xinit/xinitrc ] && mv /etc/X11/xinit/xinitrc /etc/X11/xinit/xinitrc.$$" psp
nsc_rsync /opt/dfs/tsctl2/config/xinitrc.${subtype} /etc/X11/xinit/xinitrc $subtype
