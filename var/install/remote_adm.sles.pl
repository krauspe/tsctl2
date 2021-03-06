#!/usr/bin/perl
#
# remote_adm.pl  
#
# executes commands on a list of hosts (the short explanation )
# (what really happens is magic and rather complicated :-)) )
#
# Version 4.7.9: Special very last sles version for remote piling)
# c/o Peter Krauspe , DFS , 12/15 - 11/17
#
# - 06.10.2011: added nsc_rsync
# - 25.10.2011: added dlc_sh
# - added support for different dlc root dirs (parm dlc_root in .hosts)
#   Entry dlc_root=<dir> in dlc.all.hosts sets /srv/dlc/<dir> instead of /srv/dlc/default as 
#   root dir in pxe boot menu
# - 14.02.2012: work on nsc_install function 14.02.2012
# - 26.02.2013: dlc_root option added for nsc add dlc ...
# - 13.03.2013: nsc add dlc ... now writes dlc_root entry in hosts file
# - 15.03.2013: weather display for rose 
# - 02.04.2013: renamed weather to info display for rose (includes now pilot infos)
# - 19.08.2013: reduce system hosts to list of running vms (XEN) with option USE_VM_LIST 
# - 10.10.2013: added sinatra support
# - 13.11.2013: added sysrq support for dlc clients (SIMOS-198)
# - 18.11.2013: Scripts is now movable: basedir will be determined by $FindBin lib (needs to be in a "bin" dir !!) 
# - 18.11.2013: usage function creates symlinks for all comand variants (mk_links.sh is now obsolete) 
# - 14.04.2014: vars "Exercise" and "LoadRun" will not be written in config.ini when run_<X> in *.runload is an empty string 
# - 15.04.2014: Added newsas commands: newsas_scd (control simcontroldeamon),newsas_reboot,newsas_shutdown
# - 19.05.2014: - NEW query functions: vars ip,mac,alu etc can be queried with user defined separator !!
#               - new function: nsc_get_config: collect config files from clients to nss (currently only x11)
#               - Using of changed script config_x11.sh instead of x11.sh (neu config file structure !!)
#               - NOTE: Before updating to this version, copy this to the system !!!
#                 - /srv/inst/cfg/x11/config (config dir with new structure) 
#                 - /srv/inst/scripts/scripts.d/config_x11.sh (replaces x11.sh) 
# - 04.07.2014:   - removed bug in vm list handling
#                 - added command for deleting host from system hostlist for updating data from install info after reinstall
# - 01.10.2014  - added  : set/reset/list nagios downtime manually with nsc_downtime, or automaticaly with poweron/shutdown commands
# - 10.06.2015  - nsc_poweron uses system.all.hosts now instead of newsim.all.hosts
# - 24.06.2015  - nsc_add / nsc_delete is now possible for all classes (hostslists) and list the modified hostlist
# - 01.07.2015  - changed logic of nsc_add / nsc_delete sub routines: nsc_add adds dhcp/pxe only for sys AND FORCE_MANAGE_DHCP/PXE == 1  
# - 11.08.2015  - Using default autologin user when not defined in hostlists (e.g. for remope-psp's or if someone deleted the entrys :-)
# - 28.10.2015  - SYSMAN-11236: defined new class for Remote Piloting: rnsc 
#                 - Use/create extra hostlist: rnsc.all.hosts with var "resource_nsc" listet by "nsc_adm -q rnsc"
#                 - changed: add_to_hostlist,nsc_query, %msg (for help and make links)
#                 - created new commands: remote_nsc_reboot/poweron/poeroff/shutdown
#                 - create emtpy /nss/home/remote_adm/config/rnsc.all.hosts if not exists (changed: get_host_lists)
#               - bugfix: no more dhcp-server restarts when nothing has been changed 
# - 05.11.2015  - added dlc_reboot
#               - added missing peaces for sysrq functions: now available: nsc/dlc/_sysrq
# - 24.11.2015  - changed class for nsc_rsync from system to newsim to ensure copiing remote pilot stuff to reconfigured machines
#                 Should not be a problem since newsim and system hostlists are mostly identical
# - 09.12.2015  - Add new function: nsc_destroy to remove from all hostlists and DELETE ALL INSTALL DATA
#                 added new sup promptUser
#                 DONE: remove install config stuff (rename with underlines))
#                 TODO: delete hostlist entrys !!
#                 TODO: enable system call to remove really
# - 10.12.2015  - improved nsc_get_config: x11.vars from each client will be copied as x11.<fqdn>.vars and has to be merged manually (so far)
#                 (was formerly copied from nss into x11-backupdir which is senseless) 
#                 DONE: enable system call to remove really
#
# - 06.01.2016  - SIMOS-315: Changed path for sinatra start/stop scripts  
# - 13.01.2016  - nsc_add: adding alu=<user> to hostlist line for type nsc when host is adc,psp,cwp 
# - 14.01.2016  - bugfix nsc_query: output resource_fqdn is now possible: wrong var name and declaration fixed (resource_fqdn)
# - 29.03.2016  - bugfix nsc_destroy: set host_check_enabled=0, since hosts to delete are normally not running :-)
# - 27.04.2016  - sinatra start/stop scripts are no longer in $PATH and neu path will change with newer NEWSIM releases.
#               - sub rose_audio now uses absolutie path instaed of scriptname only (was a bug in former version)
#               - sinatra scipts will now be searched in naxos/bin and naxos/scripts
#
# - 25.05.2016  - added flagfile to disable hostlist consistency update (consistency with install data)
# - 31.05.2016  - updated docu strings 
# - 01.12.2016  - changed nagios_delay to 5 s
#
#   Changes for remote piloting:
#
# - 04.10.2017  - sub manage_dhcp accepts type nsc now
# - 09.11.2017  - nsc_adm add will now replace entrys even if a host with same mac exists.
#                 This host will be replaced by the new host with same mac
# - 17.11.2017  - sub nsc_sh : changed class to "newsim"
#
# Version 4.7.9
#
# - 23.11.2017: - use sub nsc_add from centos version 4.10.x
#               - use sub manage_dhcp_entrys from centos version 4.10.x
#               - fixed bug in ported sub manage_dhcp_entrys (from centos version)
# TODO:
#  - test changes from 23.11.2017 !!
#  - implement getop::Long similiar to centos version 4.10.x
#
#use warnings;
#use strict;
use File::Basename;
use Cwd;
use FindBin;
use lib $FindBin::Bin;
require "timelocal.pl" ;
#use Switch;
# The base directory:
fileparse_set_fstype('MSWin32');

### control vars (be careful !!) ###############################

my $PRINT_CMD          = 1    ; # 1 prints out all commands, 0 does'nt
my $EXEC               = 1    ; # 0 does not execute any remote shell comands,
                                #   and creates all local  output files in $debug_basedir (nsc_adm -d / -a etc) 
                                #   (dhcpd.conf entrys , pxe files,  BUT FAKES dlc root dir !  )
                                # 1 EXECUTES EVERYTHING !! 
# debug # my $host_check_enabled = 1    ; # check host alive
my $host_check_enabled = 0    ; # check host alive

my $EXEC_OPT      = "bg"      ;  # all commnds will be ececuted in background 
my $NO_SERVICE_RESTART = $ENV{"NO_SERVICE_RESTART"}; # shell NO_SERVICE_RESTART=1 disables dhcp restart after config
# my $EXEC_OPT      = "quiet"   ;  # output goes to /dev/null
# my $EXEC_OPT      = "err_only" ; # only error messages will be printed
# my $EXEC_OPT      = "out+err" ; # stdout and errors will be printed
# my $EXEC_OPT      = "out-sep" ; # only stdout, no separator lines will be printed
my $SEPLINES	    = 1		; # 1 prints separator lines between outputs for each host
my $PRINT_COMMENTS  = 1		; # 1 prints comments 
my $PRINT_ERR       = 1    	; # 1 prints out error channel 
my $ADD_CLIENT_MSG  = 0         ; # 1 send message (wall_msg) to sup1-s1 when new dlc clients arrive
my $USE_VM_LIST     = 0         ; # 1 use only hosts which are running vms on a XEN HOST
                                  # with vm names beginning with nsi..  (very special !)
                                  # DO NOT set to 1 when not on an XEN host !!!
my $NAGIOS_DOWNTIME_HANDLING = 1; # enable/disable nagios downtime setting or resetting:
                                  #  - All shutdown commands set downtime for selected hosts
                                  #  - All "poweron" commands reset downtime
                                  # (nsc_downtime is not effected by this var !) 
#################################################################
%sleep = (
	'xdm-restart'  => 15,
	'set-wall-msg' => 3,
	'start-rose'   => 3
);
#################################################################

my $script_basedir = Cwd::realpath("$FindBin::Bin/../");
my $script_bindir = "${script_basedir}/bin";
#my $basedir = "/nss/home/remote_adm";
my $hosts_file ; 
my $configdir = "$script_basedir/config";
my $cfg_tmp_dir = "$script_basedir/tmp";
my (@HOSTS,@HOSTS_SELECTED,@PARMS);
my (@GROUPS,@GROUPS_SELECTED);
my (%IP,%MASTER_IP,%MASTER_HOST,%SLAVE_HOSTS,@SLAVES,@SLAVES_ALL,@MASTERS,@MASTERS_ALL,%MAC_HOSTS);
my (@CWP,@ADC,@SIM,@SUP,@PSP,@GROUPS);
my $prg = (split(/\//,$0))[-1];
my $expand_hostspec = "yes";
my $minargs;
my $server_ip; 
my $server_fqdn; 
my $server_dn; 
#################################################################
# check flag files
#################################################################
my $FORCE_MANAGE_DHCP = 0;
my $FORCE_MANAGE_PXE = 0;
my $HOSTLIST_CONSISTENCY_UPDATE_ENABLED = 1;

if ( -f "${script_bindir}/REMOTE_ADM_DEBUG" ) { $EXEC = 0; $host_check_enabled = 0; }
if ( -f "${configdir}/FORCE_MANAGE_DHCP" )    { $FORCE_MANAGE_DHCP = 1;}
if ( -f "${configdir}/FORCE_MANAGE_PXE" )    { $FORCE_MANAGE_PXE = 1;}
if ( -f "${configdir}/DISABLE_HOSTLIST_CONSISTENCY_UPDATE" )    { $HOSTLIST_CONSISTENCY_UPDATE_ENABLED = 0;}
### rose specific settings #######################################

my $rose_appl_dir = '/home/rose/.wine/drive_c/Program Files/rose';
my $rose_ini_dir  = $rose_appl_dir . '/bin';  
my $config_ini    = $rose_ini_dir . '/config.ini';
   $config_ini =~ s/ /\\ /g ;
my $tcpip_ini     = $rose_ini_dir . '/tcpip.ini';
   $tcpip_ini =~ s/ /\\ /g ;
my $config_ini_tpl    =  "$configdir/config.ini.tpl";

( -d $cfg_tmp_dir ) || mkdir $cfg_tmp_dir ; 

### system specific settings #######################################

my $config_backup_dir = "/srv/inst/cfg_backup";
my $x11_config_backup_dir = "${config_backup_dir}/x11/config";

my $nagios_cfg_file = "/etc/nagios/nagios.cfg";
my $nagios_default_down_time = 604800 ; # 7x24 hours
my $nagios_comment_author = "NEWSIM-POWER-OFF";
my $nagios_comment_data = "Shutdown by operator 7 days";
my $nagios_fixed = 0;
#my $nagios_delay = 600 ; # 10 minutes
my $nagios_delay = 5 ; # 10 s
my $nagios_sleep = 0.08;  # sleep time in secs (float) between set/reset commands
my $nagios_status_file="";
my $nagios_downtime_setting_enabled = 0; # will be enabled when nagios is properly configured
my @NAGIOS_CFG_FILe;
my @NAGIOS_STATUS_FILE;
my %NAGIOS_HOSTDOWNTIME=();

### client specific settings (diskless...) #######################################

@valid_client_types = ("sys","dlc","nsc","sol","rose","newsas","rnsc");
my $debug_basedir = "/nss/home/remote_adm/test";

my $pxe_cfg_dir = "/srv/inst/tftpboot/pxelinux.cfg";

my $pxe_client_dir = "/srv/inst/xchg/client";
my $pxe_client_config_dir = "${pxe_client_dir}/config";
#my $client_config_dir = $pxe_client_config_dir;


my $DHCP_CONFIG_FILE = "/etc/dhcpd.conf";
my $dlc_base = "/srv/dlc";

my %tftp_boot_file;
   $tftp_boot_file{"nsc"} = "pxelinux.0";
   $tftp_boot_file{"dlc"} = "pxelinux.0";
   $tftp_boot_file{"newsas"} = "pxelinux.0";
   $tftp_boot_file{"sol"} = "sun4u";

if ( ! $EXEC )
{
  print "\n WARNING: EXEC DISABLED. No commands will be send to any hosts  !!\n\n";
  $pxe_cfg_dir = $debug_basedir;
  $pxe_client_dir = $debug_basedir;
  $pxe_client_config_dir = "${pxe_client_dir}/config";
  $DHCP_CONFIG_FILE = "${debug_basedir}/dhcpd.conf";
  $pxe_cfg_dir = $debug_basedir;
  $pxe_client_dir = $debug_basedir; 
  $pxe_client_config_dir = "${pxe_client_dir}/config";
  $dlc_base = "${debug_basedir}/dlc";
}
##################################################################
# external scripts
##################################################################

my $naxos_home = "/nss/home/spv/newsim_rel1/active_release/depot/naxos";
my $sinatra_start_script = "";
my $sinatra_stop_script = "";

# check path of sinatra start/stop scripts

if ( -f "${naxos_home}/scripts/start_standalone_sinatra" ) 
{
  #print "${naxos_home}/scripts exists \n";
  $sinatra_start_script = "${naxos_home}/scripts/start_standalone_sinatra"; 
  $sinatra_stop_script = "${naxos_home}/scripts/kill_newsim_sinatra"; 
}
elsif ( -f "${naxos_home}/bin/start_standalone_sinatra" )
{
  #print "${naxos_home}/bin exists \n";
  $sinatra_start_script = "${naxos_home}/bin/start_standalone_sinatra"; 
  $sinatra_stop_script = "${naxos_home}/bin/kill_newsim_sinatra"; 
}

my $cmd_start_rose = "su - rose -c 'start_rose.sh'" ;
my $cmd_stop_rose  = "su - rose -c 'wineboot -e'" ;
my $cmd_start_rose_info = "su - rose -c '/nss/home/roseadm/info/bin/rose_info_display.sh start'" ;
my $cmd_stop_rose_info = "su - rose -c '/nss/home/roseadm/info/bin/rose_info_display.sh stop'" ;
my $cmd_kill_x = 'ps -ef | grep [X]11R6 | awk \'{print \$2}\' > /tmp/x  ; kill -9 \`cat /tmp/x\` ';
my $cmd_kill_newsim = "su - spv -c 'simkill all'" ;
my $cmd_kill_newsas = "su - svec -c 'simkill all'" ;
my $cmd_init_atcoach = "su - spv -c 'process_list'" ;
my $cmd_kill_vcs = "su - spv -c 'kill_vcs'" ;
my $cmd_set_wall_msg = "/usr/local/share/wall_msg/bin/set_wall_msg.sh" ;
my $cmd_mount_is = "[ -d /srv2/inst/scripts ] || mount_install_server.sh" ;
my $cmd_add_dlc_root = "/nss/diskless/bin/dlc_add_root" ;# <path> <hostname> <ip address>
my $cmd_del_dlc_root = "/nss/diskless/bin/dlc_remove_root" ;# <path> <hostname>
my $cmd_update_pxe_cfg = "/srv/inst/scripts/scripts.d/update_pxe_cfg.sh";
my %cmd_config ;
   #$cmd_config{"x11"} = "/srv2/inst/scripts/scripts.d/x11.sh -config_only" ;
   $cmd_config{"x11"} = "/srv2/inst/scripts/scripts.d/config_x11.sh -config_only" ;
   $cmd_config{"ssh"} = "/srv2/inst/scripts/scripts.d/manage_ssh_keys.sh" ;
   $cmd_config{"update_rose"} = "~rose/bin/update_rose.sh" ;
   $cmd_config{"update_rose_exe"} = "~rose/bin/update_rose_exe.sh" ;
   $cmd_config{"rollback_rose"} = "~rose/bin/rollback_rose.sh" ;
   $cmd_config{"disable_hotkeys"} = "/root/bin/config_system_hotkeys.pl disable" ;
   $cmd_config{"enable_hotkeys"} = "/root/bin/config_system_hotkeys.pl enable" ;
   $cmd_config{"create_logdir"}   = "su - spv -c 'mkdir -p \\\$ATC_ERRORLOG; chmod 775 \\\$ATC_ERRORLOG'";
   #$cmd_config{"create_logdir"}   = "su - spv -c 'echo \\\$ATC_ERRORLOG'";
##################################################################
# Process ARGS                                                    
##################################################################
my @EXCLUDED_HOSTS = ();
my @TMP = ();

for(@ARGV)
{
  next if ! /=/;
  ($parm,$val) = split(/=/);
  if ($parm eq "exclude") { @EXCLUDED_HOSTS = split(/,/,$val); }
}


for (@EXCLUDED_HOSTS)
{
  $excluded_host = $_;
  &myprint("excluded: $excluded_host\n");
  @TMP = grep(!/$excluded_host/,@HOSTS_SELECTED);
  @HOSTS_SELECTED = @TMP;
}



##################################################################
# command line / link  processing 
#################################################################

my $hostspec="";
my $host_cfg="";
my $action="";
my $class="";
my $cmd="";
my $groups_selected="";
my $use_groups=0;
my $args_not_ok=0;
my $val;
my $type_mac;
my $opt_arg;
my $mac;
my $host_check_enabled_prev ;
my $get_host_list_retval;
my $retval ;
my $client_type;
my $fqdn;

$_ = $prg;

# USE GROUPS

#/remote_adm/ && do {
#  $action   = $ARGV[0]; $host_cfg = $ARGV[1]; $class = $ARGV[2]; $groups_selected = $ARGV[3];
#  $args_not_ok = $#ARGV > 1 ? 0 : 1  ; $use_groups=1;
#};
/remote_adm.pl/ && do {$args_not_ok = 1};

/rose_adm/ && do {
  $action   = $ARGV[0]; $host_cfg = $ARGV[1]; $class  = "rose"; $groups_selected = $ARGV[2];
  $args_not_ok = $#ARGV > 0 ? 0 : 1  ; $use_groups=1;
};
/rose_reboot/ && do {
  $action   = "reboot" ; $host_cfg = $ARGV[0]; $groups_selected = $ARGV[1]; $class  = "rose"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1 ; $use_groups=1;
};
/rose_audio/ && do {
  $action   = "audio" ; $cmd = $ARGV[0] ; $host_cfg = $ARGV[1]; $groups_selected = $ARGV[2]; $class  = "rose"; 
  $args_not_ok = $#ARGV >= 1 ? 0 : 1 ; $use_groups=1;
};
/rose_autologin/ && do {
  $action = "autologin" ; $user = "rose" ; $val = $ARGV[0]; $host_cfg = $ARGV[1]; $groups_selected = $ARGV[2] ; $class  = "rose"; 
  $args_not_ok = $#ARGV > 0 && ($val eq "on" || $val eq "off") ? 0 : 1  ; $use_groups=1;
};

# USE HOSTSPECS

/nsc_adm/ && do {
  # usage:\t$PRG -a nsc xx:xx:xx:xx:xx:xx\n\t$PRG -d [nsc|all]\n\t$PRG -f file\n\t$PRG -q [nsc]
  $action   = $ARGV[0]; $host_cfg = all; $class  = "newsim"; $hostspec = $ARGV[1]; $type_mac = $ARGV[2]; $opt_arg = $ARGV[3]; $host_check_enabled_prev = $host_check_enabled ; $host_check_enabled = 0; 
  $minargs = 2; $expand_hostspec = "no";
  if ($action eq "-a" || $action eq "add" )              { $action = "add"; $class = ":dynamic:";}
  elsif ($action eq "-f" || $action eq "add_from_file" ) { $action = "add_from_file";  $expand_hostspec = "file" ; $class = ":dynamic:";}
  elsif ($action eq "-d" || $action eq "del" )           { $action = "del"; $class = ":dynamic:";}
  elsif ($action eq "-q" || $action eq "query" )         { $action = "query"; $hostspec = "all" ; $type_mac = $ARGV[1] ; $opt_arg = $ARGV[2] ;$minargs = 1 ;$class = ":dynamic:"; $SEPLINES = 0; $PRINT_COMMENTS = 0;}
  elsif ($action eq "-r" || $action eq "rebuild_all" )   { $action = "rebuild_all"; $hostspec = "all" ; $type_mac = $ARGV[1] ; $class = ":dynamic:";$minargs = 1;}
  elsif ($action eq "-rd" || $action eq "rebuild_dhcp" ) { $action = "rebuild_dhcp"; $hostspec = "all" ; $type_mac = $ARGV[1] ; $class = ":dynamic:";$minargs = 1;}
  elsif ($action eq "-rp" || $action eq "rebuild_pxe" )  { $action = "rebuild_pxe"; $hostspec = "all" ; $type_mac = $ARGV[1] ; $class = ":dynamic:";$minargs = 1;}
  elsif ($action eq "-scd" || $action eq "simcontrold" )  { $action = "simcontrold"; $hostspec = "all" ; $val = $ARGV[1] ; $class = ":dynamic:";$minargs = 1;}
  else  { $host_check_enabled = $host_check_enabled_prev; $minargs = 1; $expand_hostspec = "yes"} 
  $args_not_ok = $#ARGV >=$minargs  ? 0 : 1  ; 
};
/newsas_scd/ && do {
  $action = "cmd"; $cmd = "rcsimcontrold $ARGV[0]" ; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "newsas";
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  print "newsas_scd : args_not_ok=$args_not_ok\n" if $PRINT_COMMENTS;
};
/newsas_reboot/ && do {
  $action = "cmd"; $cmd   = "reboot" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "newsas"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/newsas_shutdown|newsas_poweroff/ && do {
  $action = "shutdown";  $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "newsas"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/dlc_poweron/ && do {
  $action = "wol"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "dlc"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; $host_check_enabled = 0; 
};
/dlc_reboot/ && do {
  $action = "cmd"; $cmd = "reboot" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "dlc"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/dlc_shutdown|dlc_poweroff/ && do {
  $action = "shutdown"; $cmd   = "halt" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "dlc"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/dlc_sysrq/ && do {
  $action = "sysrq"; $cmd = $ARGV[0] ; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "dlc"; $EXEC_OPT = "bg";
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ; $host_check_enabled = 0;
};
/sol_reboot/ && do {
  $action = "cmd"; $cmd = "init 6" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "sol"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/nsc_autologin/ && do {
  $action = "autologin" ; $user = $ARGV[0] ; $val = $ARGV[1]; $hostspec = $ARGV[2]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV > 1 && ($val eq "on" || $val eq "off") ? 0 : 1  ;
};
/nsc_autologin_on/ && do {
  $action = "autologin" ;$val  = "on" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "newsim"; undef $user;
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/nsc_autologin_off/ && do {
  $action = "autologin" ;$val  = "off" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "newsim"; undef $user;
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ;
};
/nsc_mount_is/ && do {
  $action = "mount_is" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
};
/nsc_reboot/ && do {
  $action = "reboot"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "newsim"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/nsc_poweron/ && do {
  $action = "wol"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; $host_check_enabled = 0;
};
/nsc_sysrq/ && do {
  $action = "sysrq"; $cmd = $ARGV[0] ; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "newsim"; $EXEC_OPT = "bg";
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ; $host_check_enabled = 0;
};
/nsc_shutdown|nsc_poweroff/ && do {
  $action = "shutdown"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/nsc_downtime/ && do {
  $action = "downtime"; $cmd   = $ARGV[0] ; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; $host_check_enabled = 0;
};
/nsc_config/ && do {
  $action = "config" ; $val = $ARGV[0]; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  #print "EXEC_OPT=$EXEC_OPT\n";
};
/nsc_get_config/ && do {
  $action = "get_config" ; $val = $ARGV[0]; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
};
/nsc_install/ && do {
  $action = "install" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "newsim"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ;
  if (defined $ARGV[1]) { $EXEC_OPT = $ARGV[1] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
};
/^nsc_sh$/ && do {
  $action   = "cmd" ; $cmd = $ARGV[0]; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "newsim";
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  print "nsc_sh : args_not_ok=$args_not_ok\n";
};
/remote_nsc_reboot/ && do {
  $action = "reboot"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "rnsc"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/remote_nsc_poweron/ && do {
  $action = "wol"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "rnsc"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; $host_check_enabled = 0;
};
/remote_nsc_shutdown|remote_nsc_poweroff/ && do {
  $action = "shutdown"; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "rnsc"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/^dlc_sh$/ && do {
  $action   = "cmd" ; $cmd = $ARGV[0]; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "dlc"; 
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  print "nsc_sh : args_not_ok=$args_not_ok\n";
};
/^nsc_rsync$/ && do {
  $action   = "rsync" ; $rsync_from = $ARGV[0]; $rsync_to = $ARGV[1];$hostspec = $ARGV[2]; $rsync_opt = $ARGV[3]; 
  #$host_cfg = "all" ; $class  = "system"; 
  $host_cfg = "all" ; $class  = "newsim"; 
  if (defined $ARGV[4]) { $EXEC_OPT = $ARGV[4] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  $args_not_ok = $#ARGV >= 2 ? 0 : 1  ;
};
/^sol_sh$/ && do {
  $action   = "cmd" ; $cmd = $ARGV[0]; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "sol"; 
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  print "sol_sh : args_not_ok=$args_not_ok\n";
};
/sol_install/ && do {
  $action = "cmd"; $cmd  = "reboot -- \'net:dhcp - install\'" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "sol"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/sol_poweroff|sol_halt/ && do {
  $action = "cmd"; $cmd  = "init 5" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "sol"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ; 
};
/nsc_msg/ && do {
  $color = $ARGV[2] ne "" ? $ARGV[2] : "black" ; 
  $action = "cmd"; $cmd = "$cmd_set_wall_msg newsim \'" . $ARGV[0] . "\' $color" ; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "system"; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1 ; 
};
/^dev_sh$/ && do {
  $action   = "cmd" ; $cmd = $ARGV[0]; $hostspec = $ARGV[1]; $host_cfg = "all" ; $class  = "dev";
  $args_not_ok = $#ARGV >= 1 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
  print "nsc_sh : args_not_ok=$args_not_ok\n";
};
/dev_mount_is/ && do {
  $action = "mount_is" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "dev";
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ;
  if (defined $ARGV[2]) { $EXEC_OPT = $ARGV[2] ; $EXEC_OPT =~ s/^-+// ;} else {$EXEC_OPT = "out+err";}
  if ($EXEC_OPT eq "out-only") {$SEPLINES = 0; $PRINT_CMD = 0 ; $PRINT_ERR = 0; $PRINT_COMMENTS = 0}
};

/nsc_destroy/ && do {
  $action = "destroy" ; $hostspec = $ARGV[0]; $host_cfg = "all" ; $class  = "system";
  $host_check_enabled=0; 
  $args_not_ok = $#ARGV >= 0 ? 0 : 1  ;
};


$msg = {
    nsc_reboot          => "\nusage: nsc_reboot    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    dlc_reboot          => "\nusage: dlc_reboot    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    dlc_poweron         => "\nusage: dlc_poweron   <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    dlc_poweroff        => "\nusage: dlc_poweroff   <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    dlc_shutdown        => "\nusage: dlc_shutdown   <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    dlc_sysrq           => "\nusage: dlc_sysrq <s=sync|b=reboot|o=poweroff|u=umount|q=quit> (arg is only the letter !!) <hostspec>\n\n",
    sol_reboot          => "\nusage: sol_reboot    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    sol_halt            => "\nusage: sol_halt    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    sol_poweroff        => "\nusage: sol_poweroff    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    sol_install         => "\nusage: sol_poweroff    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    nsc_poweron         => "\nusage: nsc_poweron  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    nsc_shutdown        => "\nusage: nsc_shutdown  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    nsc_downtime        => "\nusage: nsc_downtime <set|reset|list> <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    nsc_poweroff        => "\nusage: nsc_poweroff  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    nsc_sysrq           => "\nusage: nsc_sysrq <s=sync|b=reboot|o=poweroff|u=umount|q=quit> (arg is only the letter !!) <hostspec>\n\n",
    nsc_autologin       => "\nusage: nsc_autologin  <user> <on|off> <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist)\n\n",
    nsc_autologin_on    => "\nusage: nsc_autologin_on    <hostspec> (enables autologin as defined in config/hostlist ) \n\n" , 
    nsc_autologin_off   => "\nusage: nsc_autologin_off   <hostspec> (disables autologin)\n\n" ,
    nsc_config          => "\nusage: nsc_config <option> <hostspec> (valid options: x11, ssh, update_rose, update_rose_exe )\n\n" ,
    nsc_get_config      => "\nusage: nsc_get_config <option> <hostspec> (valid options: x11 )\n\n" ,
    nsc_install         => "\nusage: nsc_install <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)\n\n" ,
    nsc_mount_is        => "\nusage: nsc_mount_is <hostspec> (mounts install server filesystems)\n\n" ,
    nsc_msg             => "\nusage: nsc_msg <message>   <hostspec> (show message in backdrop windows )\n\n" ,
    nsc_destroy         => "\nusage: nsc_destroy <hostspec> (remove hosts from system,newsim,and rose hostslists and DELELE INSTALL DATA !! )\n\n" ,
    remote_nsc_reboot   => "\nusage: remote_nsc_reboot    <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    remote_nsc_poweron  => "\nusage: nsc_poweron  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    remote_nsc_shutdown => "\nusage: remote_nsc_shutdown  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    remote_nsc_poweroff => "\nusage: remote_nsc_poweroff  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(cwp,psp,sim etc)) \n\n",
    rose_reboot         => "\nusage: rose_reboot <cfg>   [<group1>,<group2>,..>] \n\n",
    rose_audio          => "\nusage: rose_audio <start|stop> <cfg> [<group1>,<group2>,..>] \n\n",
    rose_autologin      => "\nusage: rose_autologin on|off   <cfg> [<group1>,<group2>,..>] \n\n",
    newsas_reboot       => "\nusage: newsas_reboot  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(nsi etc)) \n\n",
    newsas_shutdown     => "\nusage: newsas_shutdown  <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(nsi etc)) \n\n",
    newsas_scd          => "\nusage: newsas_scd  <start|stop|restart|status> <hostspec> (hostspec = host|hostlist|hosttype|hosttypelist(nsi etc)) \n\n",
    nsc_adm	        => "\
        \n\
	-------------------------------------------------------------------------------------\
        Usage :\n\
  	nsc_adm <action> <hostspec> [<parms>]\
	-------------------------------------------------------------------------------------\
  	\
        where:\
  	<hostspec> is a comma separated list of hosts or host types like cwp,psp,sup,sim etc \
  	\
  	examples:\
	\
  	nsc_adm  init  all\
  	nsc_adm  uptime cwp,psp\
  	nsc_adm  reboot sim\
  	\
  	\
	valid actions are:\

  	init  :   kill unwanted processes, set autologin for application user, restart window manager, set wallpaper\
  	start :   not yet implemented\
  	stop  :   not yet implemented\
  	uptime:   prints out uptime for selected machines \
  	reboot:   reboot selected machines> \
                  for reboot of diskless clients use dlc_reboot\
                  for reboot of solaris  clients use sol_reboot\
  	kill_x:   kill X server on selected machines\
  	kill_sim: simkill all on selected machines\
  	kill_vcs: kill_vcs all on selected machines\

	special actions:\

        -a  | add <host>   <type>:<mac> [<dlc_root>] : add    client of type <type>\
        -d  | del <host>   <type>       : delete client of type <type>\
                                          USE nsc_adm -d <host> sys when replacing a nsc client !!!\
                                          This forces all hostlists (not DLCs) to be updated \

        -q  | query   <type> [\"var1 var2 var3\"] : query hostlist of type <type>\
        -rd | rebuild_dhcp <type>       : rebuild dhcp entrys in /etc/dhcpd.conf\
        -rp | rebuild_pxe  <type>       : rebuild pxe files (mac file and boot menu)\
        -r  | rebuild      <type>       : rebuild dhcp, pxe and diskless client root dir(s)\

        valid types currently: sol   : solaris clients,    (dhcp entrys)\
                               dlc   : diskless client, (dhcp,pxe entrys))\
			       newsas: newsas virtual machines (dhcp entrys)\
                               nsc   : all other newsim clients\
                               rnsc   : all remote nscs (psp)\
                               rose  : all rose clients, list query only!)\
                               sys   : all clients, from system.all.hosts\

	HINT: add parameter dlc_root=<alternate_root_dir> to dlc.all.hosts to enforce\
              mount of another root dir instead of default\
              OR add dlc_root (e.g. ico) as last value in nsc_adm add .. command

	more examples:\

	nsc_adm add cwp1-s2 dlc:00:18:f3:f3:00:17      # add diskless client\
	nsc_adm add cwp1-s2 dlc:00:18:f3:f3:00:17 ico  # add diskless client using ico root fs\
	nsc_adm  -a cwp1-s2 dlc:00:18:f3:f3:00:17      # the same as above\ 
	nsc_adm del cwp1-s2 dlc\                       # delete diskless client\
	nsc_adm add psp100-s1 nsc:00:18:f3:f3:00:17    # add nsc client 
	nsc_adm add psp100-s1 sys:00:18:f3:f3:00:17    # add nsc client \
						       # (adds dhcp/pxe entry if Flagfile(s) FORCE_MANAGE_DHCP/FORCE_MANAGE_PXE exists)\
	\
	nsc_adm  -a siu3-s1 sol:00:18:f3:f3:00:18      # add solaris client (dhcp entry only)\
	nsc_adm  -q dlc             # list all diskless clients\
	nsc_adm  -q sol             # list all solaris clients\
	nsc_adm  -q nsc             # list all newsim nsc clients\
	nsc_adm  -q nsc \"mac ip\"   # list all newsim nsc clients with mac address and ip address. separated by spaces\
	nsc_adm  -q nsc \"mac;ip\"   # list all newsim nsc clients with mac address and ip address. separated by semicolons\
	-------------------------------------------------------------------------------------\
  	\n\n",
    rose_adm	      => "\
        \n\
	-------------------------------------------------------------------------------------\
        Usage :\n\
  	rose_adm <[init|start|stop|uptime|reboot]> <cfg> [<group1>,<group2>, ...]\
	-------------------------------------------------------------------------------------\
  	\
        where:\
        cfg   = config, e.g. basic,croatia,aps,all,6x4,..\
  	\
  	examples:\
	\
  	rose_adm init  croatia\
  	rose_adm start basic\
  	rose_adm start basic 1,3,4   # start only groups 1,3 and 4 (NO blanks !!)\ 
  	\
  	init  : set autologin for application user and restart window manager\
  	        distribute tcpip.ini,config.ini\
  	start : start application \
  	stop  : stop  application \n\
  	reboot: reboot all machines configured for <cfg> \n\
  	uptime: prints out uptime for all machines from <cfg> \n\
	-------------------------------------------------------------------------------------\
  	\n\n",
#    remote_adm	      => "\
#        \n\
#	-------------------------------------------------------------------------------------\
#        Usage :\n\
#  	remote_adm <[init|start|stop|uptime|reboot]> <cfg> <class> [<group1>,<group2>, ...]\
#	-------------------------------------------------------------------------------------\
#  	\
#        where:\
#        cfg   = config, e.g. basic,croatia,aps,all,6x4,..\
#        class = application (newsim,rose) \
#  	\
#  	examples:\
#	\
#  	remote_adm  init  all newsim\
#  	remote_adm  start 6x4 newsim\
#  	\
#  	remote_adm start basic rose\
#  	remote_adm start basic rose 1,3,4   # start only groups 1,3 and 4 (NO blanks !!)\ 
#  	remote_adm init  croatia\
#  	\
#  	init  : set autologin for application user and restart window manager\
#  	        distribute tcpip.ini,config.ini\
#	\
#  	start : start application \
#  	stop  : stop  application \n\
#  	reboot: reboot all machines configured for <cfg> \n\
#  	uptime: prints out uptime for all machines from <cfg> \n\
#	-------------------------------------------------------------------------------------\
#  	\n\n",
    nsc_sh	      => "\
        \n\
	-------------------------------------------------------------------------------------\
	Run shell command on selected hosts
	-------------------------------------------------------------------------------------\
        Usage :\n\
  	nsc_sh <command> <host>|<hostspec> \n\
	-------------------------------------------------------------------------------------\
  	\
  	  where:\
	\
  	  <command>  is a (quoted) shell command \
  	  <host>     is a comma separated list of hosts \
  	  <hostspec> is a comma separated list of types like cwp,psp,sup,sim etc \
                         or \"all\"  to get all installed clients  \
  	\
  	examples:\
  	\
  	nsc_sh \"reboot\" psp       # to reboot machines of type cwp\
  	nsc_sh \"date\" psp,cwp     # to run date command on each psp and cwp   
  	nsc_sh \"uptime\" cwp1-s1,psp2-s1,sim1-s1
  	nsc_sh \"ps -ef | grep my_proc\" cwp1-s1,psp2-s1,sim1-s1
	\
	hints:\
        - quotes may be ommitted, when command is only one string without white spaces)\ 
        - hosts given by hosttypes are determined from installed hosts (NOT a list in config dir !) \ 
	-------------------------------------------------------------------------------------\
  	\n\n",
    remote_nsc_sh	      => "\
        \n\
	-------------------------------------------------------------------------------------\
	Run shell command on selected hosts (from list rnsc.all.hosts)
	-------------------------------------------------------------------------------------\
        Usage :\n\
  	remote_nsc_sh <command> <host>|<hostspec> \n\
	-------------------------------------------------------------------------------------\
  	\
  	  where:\
	\
  	  <command>  is a (quoted) shell command \
  	  <host>     is a comma separated list of hosts \
  	  <hostspec> is a comma separated list of types like cwp,psp,sup,sim etc \
                         or \"all\"  to get all installed clients  \
  	\
  	examples:\
  	\
  	remote_nsc_sh \"reboot\" psp       # to reboot machines of type cwp\
  	remote_nsc_sh \"date\" psp,cwp     # to run date command on each psp and cwp   
  	remote_nsc_sh \"uptime\" cwp1-s1,psp2-s1,sim1-s1
  	remote_nsc_sh \"ps -ef | grep my_proc\" cwp1-s1,psp2-s1,sim1-s1
	\
	hints:\
        - quotes may be ommitted, when command is only one string without white spaces)\ 
        - hosts given by hosttypes are determined from installed hosts (NOT a list in config dir !) \ 
	-------------------------------------------------------------------------------------\
  	\n\n",
    nsc_rsync	      => "\
        \n\
	-------------------------------------------------------------------------------------\
	copy files/dirs using rsync
	-------------------------------------------------------------------------------------\
        Usage :\n\
  	nsc_rsync <from> <to> <hostspec> <additional rsync options> \n\
	-------------------------------------------------------------------------------------\
  	\
  	  where:\
	\
  	  <from>  is a source file or dir \
  	  <to>    is a destination file or dir on remote hosts \
  	  <hostspec> is a comma separated list of types like cwp,psp,sup,sim etc \
                         or \"all\"  to get all installed clients  \
  	\
  	examples:\
  	\
  	nsc_rsync /srv/inst/scripts/sbin /srv/inst/scripts all
  	nsc_rsync /srv/inst/scripts/sbin /srv/inst/scripts cwp,psp1-s1 --dry-run 
  	nsc_rsync my_scripts.sh /some/dir cwp1-s1,cwp3-s2,adc
	\
	-------------------------------------------------------------------------------------\
  	\n\n",
    sol_sh	      => "\
        \n\
	-------------------------------------------------------------------------------------\
	Run shell command on selected solaris hosts
	-------------------------------------------------------------------------------------\
        Usage :\n\
  	sol_sh <command> <host>|<hostspec> \n\
	-------------------------------------------------------------------------------------\
  	\
  	  where:\
	\
  	  <command>  is a (quoted) shell command \
  	  <host>     is a comma separated list of hosts \
  	  <hostspec> is a comma separated list of types like cwp,psp,sup,sim etc \
                         or \"all\"  to get all installed clients  \
  	\
  	examples:\
  	\
  	nsc_sh \"date\" psp,cwp     # to run date command on each psp and cwp   
  	nsc_sh \"uptime\" cwp1-s1,psp2-s1,sim1-s1
  	nsc_sh \"ps -ef | grep my_proc\" cwp5-s2,cwp6-s2
	\
	hints:\
        - quotes may be ommitted, when command is only one string without white spaces)\ 
        - hosts given by hosttypes are determined from installed hosts (NOT a list in config dir !) \ 
	-------------------------------------------------------------------------------------\
  	\n\n"
};

sub myprint
{
  my $string = shift;
  if ($PRINT_COMMENTS){ print $string ; }
}

sub usage
{
  my $prg = shift;
  if (defined $msg->{$prg}) {print $msg->{$prg};}
  else 
  { 
    #print "\nfor $prg is no help available !!\n\n";
    for $command (keys %$msg) 
    {
      $prg = $command; print $msg->{$prg} ;
      if ( -d "$script_bindir" && ! -f "${script_bindir}/$command"  )
      {   
        system("cd $script_bindir; ln -s remote_adm.pl $command");
      } 
    }
  }
  exit(1);
}

my %call_sub =
(
   rose => {
     "init"          => \&rose_init    ,
     "start"         => \&rose_start   ,
     "stop"          => \&rose_stop    ,
     "audio"         => \&rose_audio  ,
     "reboot"        => \&rose_reboot  ,
     "uptime"        => \&rose_uptime  , 
     "autologin"     => \&rose_autologin  ,
     "query"         => \&nsc_query    ,
     "cmd"           => \&nsc_sh       
   },
   newsim => {
     "init"          => \&nsc_init    ,
     "start"         => \&nsc_start   ,
     "stop"          => \&nsc_stop    ,
     "kill_x"        => \&nsc_kill_x  ,
     "kill_sim"      => \&nsc_kill_newsim  ,
     "kill_vcs"      => \&nsc_kill_vcs  ,
     "uptime"        => \&nsc_uptime  , 
     "autologin"     => \&nsc_autologin,
     "add"           => \&nsc_add    ,
     "add_from_file" => \&nsc_add_from_file ,
     "del"           => \&nsc_del    ,
     "query"         => \&nsc_query    ,
     "shutdown"      => \&nsc_shutdown  ,
     "wol"           => \&nsc_wol     ,
     "install"       => \&nsc_install ,
     "reboot"        => \&nsc_reboot  ,
     "sysrq"         => \&nsc_sysrq   ,    
     "rsync"         => \&nsc_rsync  ,
     "cmd"           => \&nsc_sh       
   },
   dlc => {
     "add"           => \&nsc_add    ,
     "add_from_file" => \&nsc_add_from_file ,
     "del"           => \&nsc_del    ,
     "query"         => \&nsc_query    ,
     "rebuild_all"   => \&nsc_rebuild    ,
     "rebuild_dhcp"  => \&nsc_rebuild    ,
     "rebuild_pxe"   => \&nsc_rebuild    ,
     "cmd"           => \&nsc_sh      , 
     "shutdown"      => \&nsc_shutdown  ,
     "reboot"        => \&nsc_reoot    ,
     "wol"           => \&nsc_wol     ,
     "sysrq"         => \&nsc_sysrq       
   },
   sol => {
     "add"           => \&nsc_add    ,
     "del"           => \&nsc_del    ,
     "query"         => \&nsc_query    ,
     "rebuild_all"   => \&nsc_rebuild    ,
     "rebuild_dhcp"  => \&nsc_rebuild    ,
     "cmd"           => \&nsc_sh       
   },
   newsas => {
     "add"           => \&nsc_add    ,
     "del"           => \&nsc_del    ,
     "query"         => \&nsc_query    ,
     "rebuild_all"   => \&nsc_rebuild    ,
     "rebuild_dhcp"  => \&nsc_rebuild    ,
     "shutdown"      => \&nsc_shutdown  ,
     "cmd"           => \&nsc_sh       
   },
   rnsc => {
     "add"           => \&nsc_add    ,
     "del"           => \&nsc_del    ,
     "query"         => \&nsc_query    ,
     "shutdown"      => \&nsc_shutdown  ,
     "reboot"        => \&nsc_reboot  ,
     "sysrq"         => \&nsc_sysrq   ,
     "wol"           => \&nsc_wol     ,
     "cmd"           => \&nsc_sh       
   },
   dev => {
     "cmd"   => \&nsc_sh       ,
     "autologin" => \&nsc_autologin ,
     "mount_is" => \&nsc_mount_is ,
     "config" => \&nsc_config
   },
   system => {
      "add"           => \&nsc_add    ,
      "del"           => \&nsc_del    ,
      "cmd"           => \&nsc_sh       ,
      "autologin"     => \&nsc_autologin ,
      "mount_is"      => \&nsc_mount_is ,
      "config"        => \&nsc_config  ,
      "get_config"    => \&nsc_get_config  ,
      "rsync"         => \&nsc_rsync  ,
      "query"         => \&nsc_query  ,
      "del"           => \&nsc_del    ,
      "shutdown"      => \&nsc_shutdown  ,
      "wol"           => \&nsc_wol     ,
      "sysrq"         => \&nsc_sysrq   ,
      "downtime"      => \&nsc_downtime ,
      "destroy"       => \&nsc_destroy
   }
);

#debug
#print "continue .....\n\n\n";
#exit(0);

###### MAIN ###############################
 
# rose: clean cfg_tmp_dir #-------------

if ( $args_not_ok ) { &usage($prg); }

if ( -d $cfg_tmp_dir) 
{ 
  system "touch $cfg_tmp_dir/flag";
  system "rm $cfg_tmp_dir/*";
}
else
{ 
  mkdir $cfg_tmp_dir;
}
#--------------------------------------------
# handle s some globals 
#--------------------------------------------

$client_type = $class; 
if ($class eq ":dynamic:")
{
  $class = $type_mac ;
  $class =~ s/:.*// ;
  $mac = $type_mac ;
  $mac   =~ s/^$class://;
  if ($mac eq $class) {$mac = ""}
  #print "type_mac=\'$type_mac\' \n";
  #print "class=\'$class\'\n";
  #print "mac=\'$mac\'\n";

  $client_type = $class; 
  if ($class eq "nsc") {$class = "newsim";}
  if ($class eq "sys") {$class = "system";} 
  &myprint("check client_type:$client_type\n");
  if ($client_type eq "" ) {print "client_type ist empty !\n"; &usage($prg);}
  if ( ! grep(/^$client_type$/,@valid_client_types) ) {print "client_type $client_type not valid !\n";&usage($prg);}
  #exit(0); 
}

# debug

#print "class=$class\n";
#print "check mac=$mac\n";
#print "hostspec=$hostspec\n";
#exit(0);

#--------------------------------------------
#  READ HOSTLISTS
#--------------------------------------------

#print "vor get_host_lists mac=$mac\n";
$get_host_list_retval = &get_host_lists($class,$host_cfg,$hostspec,$expand_hostspec);
#print "nach get_host_lists mac=$mac\n";
&load_run_file($class,$host_cfg);

&myprint("action=$action\n");
&myprint("class=$class\n");  

if ($call_sub{$class}{$action}) { $call_sub{$class}{$action}->(); } 
else                         { print "\n$prg: call_sub{$class}{$action} is not defined\n";exit(1);}


###### SUBS ###############################


# add client 

sub nsc_add
{
  my $ip;
  my $entry;
#  my $server_ip; 
#  my $server_fqdn; 
  my $hn = $hostspec; # $hostspec kann (darf) hier nur ein hostname sein
  my $dn;
  ($ip,$fqdn) = &get_ip($hostspec);
  $dn = $fqdn ; $dn =~ s/^[^\.]+\.//; 
  # to check: wieso funktioniert $server_ip,$server_fqdn global (zB in manage_pxe_entrys) ??
  ($server_ip,$server_fqdn) = &get_ip("is01");
  print "ip=$ip\n";
  print "hn=$hn\n";
  print "dn=$dn\n";
  print "fqdn=$fqdn\n";
  print "server_ip=$server_ip\n";
  my $changed_dhcp_config ;

  # check ip adress

  if  (  $ip !~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)
  {
     print "\ncan not resolv $hn !!\n\n"; 
     return 1;
  }

  # if mac is not given as arg, use mac from hostlist when available
  if ($mac eq "")
  {
    if (defined $MAC{$fqdn}) {
      $mac = $MAC{$fqdn};
      print "\nMAC address not given. Using $mac from hostlist.\n\n";
    } else {
      print "\nNO MAC address is NOT available from args or hostlist !!\n\n";
      return 1;
    }
  }

  # check mac adress (e.g. 00:15:F2:04:23:14)

  if  (  $mac !~ /[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}/)
  {
     print "\n$mac is not a MAC adress !!\n\n"; 
     return 1;
  }

  $retval = &add_to_hostlist($class,$host_cfg,$hn,$mac,$client_type,$opt_arg);
  
  # only for print
  $hosts_file = $configdir . '/' . $class . '.' . $host_cfg . '.hosts' ; 

  if ($retval <= 0)
  {
    #rcmd("$cmd_set_wall_msg newsim 'NEW dlc client: '${hn}'...' yellow ","sup1-s1","0","0") if ($ADD_CLIENT_MSG && $client_type eq "dlc");
    #system("sleep 3");
    print " -------------------------------------\n";
    if ($retval == -1) {print " host $hn with mac $mac confirmed in $hosts_file\n";}
    elsif ($retval == -2) {print " changed mac for known host $hn to $mac in $hosts_file\n";}
    # TODO: test
    elsif ($retval == -3)
    {
      print " changed hostname for known mac $mac to $hn in $hosts_file\n";
      $changed_dhcp_config = &manage_dhcp_entrys("del",$MAC_HOSTS{$mac},$mac,$ip,$client_type);
    }
    else  {print " host $hn with mac $mac added to $hosts_file\n";}

    # add dhcp entry
    $changed_dhcp_config = &manage_dhcp_entrys("del",$hn,$mac,$ip,$client_type);
    $changed_dhcp_config = &manage_dhcp_entrys("add",$hn,$mac,$ip,$client_type);
    if ( $EXEC && $NO_SERVICE_RESTART == 0 && $changed_dhcp_config == 1 ) 
    {
       print " restarting dhcpd ...\n";
       system("rcdhcpd restart");
    }

    # add pxe entry
    $retval = &manage_pxe_entrys("add",$mac,$ip,$hn,$dn,$client_type,$opt_arg);

    # add dlc root dir  # ab diskless-0.4.3 werden keine root mehr ngelegt, aber der ssh key kopiert
    #$retval = &manage_dlc_root("add",$dlc_base,$hn,$ip,$client_type); 
    # send message
    rcmd("$cmd_set_wall_msg newsim 'NEW dlc client: '${hn}' ready' green ","sup1-s1","0","0") if ($ADD_CLIENT_MSG && $client_type eq "dlc");;
  }
  elsif ($retval == 1) # no longer used. entry will be replaced
  {
    print "****************************************\n";
    print "host not added (delete  $hn first !) !!!\n\n";
    print "****************************************\n";
  }
  elsif ($retval == 2) # no longer used. entry will be replaced
  {
    print "****************************************\n";
    print "host not added (delete $MAC_HOSTS{$mac} first !) !!!\n\n";
    print "****************************************\n";
  }
  elsif ($retval == 3)
  {
    print "****************************************\n";
    print "host not added: client type $client_type not supported !\n\n";
    print "****************************************\n";
  }
  $retval = $retval <= 0 ? 0 : $retval ;
  #print "retval=$retval\n";
  exit($retval);
}


sub manage_dlc_root #  obsolete ab diskless-0.4.3
{
  my $action      = shift ;
  my $dlc_base    = shift ;
  my $hn          = shift ;
  my $ip          = shift ;
  my $client_type = shift ;
  my @CMD_OUT;

  if ($client_type ne "dlc" ) {print " manage_dlc_root: no task for client type $client_type\n"; return;}
  
  if ($action eq "add")
  {
    ( -d $dlc_base ) ||  system("mkdir $dlc_base");

    #print " manage_dlc_root: call $cmd_add_dlc_root $dlc_base $hn $ip\n";
    
    if ($EXEC) 
    {
      #@CMD_OUT = `$cmd_add_dlc_root $dlc_base $hn $ip $server_ip 2>1` ; obsolete ab diskless-0.4.3
      #for (0..$#CMD_OUT) {$CMD_OUT[$_] =~ s/^/ / ; }
      #print @CMD_OUT;
      print " manage_dlc_root: copiing id_dsa.pub\n"; 
      system("cat /root/.ssh/id_dsa.pub >> ${dlc_base}/${hn}/root/.ssh/authorized_keys") if $EXEC;
    }
    else 
    { 
      print " manage_dlc_root: nothing to do in debug mode. \n";
      #print " manage_dlc_root: copiing id_dsa.pub\n"; 
      #system("mkdir ${dlc_base}/${hn}"); print " FAKE add dlc root: ${dlc_base}/${hn}\n";
    }

  }
  elsif ($action eq "del")
  {
    print " manage_dlc_root: nothing to do. \n";
    #print " manage_dlc_root: call $cmd_del_dlc_root $dlc_base $hn \n";
    #@CMD_OUT = `$cmd_del_dlc_root $dlc_base $hn 2>1` ;
    #for (0..$#CMD_OUT) {$CMD_OUT[$_] =~ s/^/ / ; }
    #print @CMD_OUT;
  }
  return(0);
}

# CHANGES HERE

# manage  dhcp entry

sub manage_dhcp_entrys
{
  my $action = shift;
  my $hn = shift;
  my $mac  = shift;
  my $ip   = shift;
  my $client_type = shift;
  my $lockfile = "${DHCP_CONFIG_FILE}.lock";
  my $DHCP_CONFIG;
  my $match;
  my $retval;

  # rempil changes: manage_dhcp_entrys accepts client type nsc and rnsc
  #if ($client_type eq "dlc" || $client_type eq "sol" || $client_type eq "newsas" || ($client_type eq "sys" && $FORCE_MANAGE_DHCP == 1) )
  if ($client_type eq "dlc" || $client_type eq "nsc" || $client_type eq "newsas" || ($client_type eq "sys" && $FORCE_MANAGE_DHCP == 1) )
  {
    if ($action eq "add")
    {
      while (-f $lockfile)
      {
         print " manage_dhcp_entrys: waiting for $lockfile to be deleted ...\n" ;
         system("sleep 1");
      }
      system("touch $lockfile");

      open(CONF,">>$DHCP_CONFIG_FILE") || die "can't open $DHCP_CONFIG_FILE";

  my $entry = "\
host $hn \{\
	filename \"$tftp_boot_file{$client_type}\"\;\
	hardware ethernet $mac\;\
	option host-name \"$hn\"\;
	fixed-address $ip\;\
\}\n";
    #print $entry;
      print CONF $entry;
      close DHCP_CONF;
      system("rm $lockfile");
      print " added dhcp entry for $hn\n";
    }
    elsif ($action eq "del")
    {
      while (-f $lockfile)
      {
         print " manage_dhcp_entrys: waiting for $lockfile to be deleted ...\n" ;
         system("sleep 1");
      }
      system("touch $lockfile");
      ( -f $DHCP_CONFIG_FILE ) || system("touch $DHCP_CONFIG_FILE");
      open(DHCP_CONF,$DHCP_CONFIG_FILE) || die "can't open $DHCP_CONFIG_FILE";
      while(<DHCP_CONF>)
      {
        $DHCP_CONFIG .= $_ ;
      }
      close DHCP_CONF;
      $match = $DHCP_CONFIG =~ s/host\s+$hn\s+\{(.|\n)*?\}\n*//g;
      #$match = $DHCP_CONFIG =~ s/\nhost\s+$hn\s+\{(.|\n)*?\}\n*//g;
      if ($match)
      {
        # ensure one and only one \n is at the end of the string
        $DHCP_CONFIG =~ s/\n+$/\n/;
        open(DHCP_CONF,">$DHCP_CONFIG_FILE") || die "can't open $DHCP_CONFIG_FILE";
        print DHCP_CONF $DHCP_CONFIG;
        close DHCP_CONF;
        print " deleted dhcp entry for $hn\n";
      }
      else {print " $hn not found in $DHCP_CONFIG_FILE\n";}
      system("rm $lockfile");
    }
    $retval=1;  # we have changed something
  }
  else
  {
     print " manage_dhcp_entrys: no task for client type $client_type\n"; 
     $retval=0; # we have changed nothing
     return($retval);
  }
}
# add pxe entry

sub manage_pxe_entrys # ($action,$mac,$ip,$hn,$dn,$client_type,$opt_arg)
{
  my $action      = shift;
  my $mac         = shift;
  my $ip          = shift;
  my $hn        = shift;
  my $dn        = shift;
  my $client_type = shift;
  my $dlc_root     = shift; # = $opt_arg
  my $config_dir;
  my $lines;
  my $file;
  my $fqdn        = "${hn}.${dn}";
  my $nlines;
  my $f;

  if ($client_type ne "dlc" || ($FORCE_MANAGE_PXE == 1 && $client_type == "sys") ) {print " manage_pxe_entrys:  no task for client type $client_type\n"; return;}

#   test -f $pxe_cfg_dir/png/${fqdn}.png && bg=${fqdn}.png
  $bg            = "dlc.png";
  $mac_file      = "${pxe_client_dir}/pxe-hw.${mac}.${fqdn}" ;
  $config_dir    = "${pxe_client_config_dir}/${fqdn}";
  $pxe_mac_file  = "${fqdn}.${client_type}.pmf";
  $pxe_host_menu = "${fqdn}.${client_type}.phm";
  #debug
  #print "manage_pxe_entrys: mac=$mac\n";
  #print "manage_pxe_entrys: ip=$ip\n";
  #print "manage_pxe_entrys: fqdn=$fqdn\n";
  #print "manage_pxe_entrys: client_type=$client_type\n";
  #print "manage_pxe_entrys: mac_file=$mac_file\n";
  #print "manage_pxe_entrys: config_dir=$config_dir\n";
  #print "manage_pxe_entrys: pxe_mac_link=$pxe_mac_link\n";
  #print "manage_pxe_entrys: pxe_mac_file=$pxe_mac_file\n";
  #print "manage_pxe_entrys: pxe_host_menu=$pxe_host_menu\n";


  if ($action eq "add")
  {

   # 1. client spezifischen pxe link bzw file erstellen /loeschen

   $pxe_mac_link  = "01-${mac}" ; $pxe_mac_link =~ s/:/-/g ;
   open(PXE_MAC_FILE,"> ${pxe_cfg_dir}/${pxe_mac_file} ") || die "can't create ${pxe_cfg_dir}/${pxe_mac_file}";

   #print "action=add\n\n";
  
   print " created pxe_mac_file ${pxe_cfg_dir}/${pxe_mac_file}\n";
  
   if ($dlc_root eq "")
   {
     if (defined $DLC_ROOT{$hn})
     {
        $dlc_root = $DLC_ROOT{$hn};
     }
   else 
     {
       $dlc_root = "default" ;
     }
   }

   @LINES = "
ALLOWOPTIONS 0
NOESCAPE 0
PROMPT 0
KBDMAP pxelinux.cfg/modules/de.ktl
DEFAULT pxelinux.cfg/modules/vesamenu.c32
APPEND pxelinux.cfg/hosts/$pxe_host_menu
";
   print PXE_MAC_FILE @LINES;

   ( -e "${pxe_cfg_dir}/${pxe_mac_link}" ) && unlink "${pxe_cfg_dir}/${pxe_mac_link}"; 
   system("cd ${pxe_cfg_dir}; ln -s ${pxe_mac_file} ${pxe_mac_link}");
   print " created pxe mac link  ${pxe_cfg_dir}/${pxe_mac_link}\n";

   # 2. client spezifisches host menu erstellen/loeschen
   ( -d "${pxe_cfg_dir}/hosts" ) || system("mkdir ${pxe_cfg_dir}/hosts");

   open(PXE_HOST_MENU,"> ${pxe_cfg_dir}/hosts/${pxe_host_menu} ") || die "can't open ${pxe_cfg_dir}/hosts/${pxe_host_menu}";


   @LINES = " 
menu title boot menu for host \"$fqdn\"
menu background pxelinux.cfg/png/$bg
default $fqdn
menu color unsel 37;40 #ff8093a1 #00000000 std
menu color title 37;40 #00000000 #fff0000 all
menu color sel 7;37;40 #ff1c2a33 #667799bb all
menu color hotsel 1;7;37;40 #ffff8b00 #667799bb all
menu color timeout_msg 37;40 #ff1c2a33 #00000000 none
menu color timeout 1;37;40 #ffff8b00 #00000000 std

timeout 50

LABEL $fqdn
  kernel dlc/vmlinuz
  append initrd=dlc/initrd nfsroot=$server_ip:${dlc_base}/${dlc_root} dhcp=eth0 readonlyroot
    
LABEL local
LOCALBOOT 0
  ";
   # append root=/dev/nfs initrd=dlc/initrd nfsroot=$server_ip:${dlc_base}/${hn} ip=$ip:$server_ip:$server_ip:255.255.255.0:$hn:eth0:off rw
   print PXE_HOST_MENU @LINES;
   close PXE_HOST_MENU;
   print " created pxe_host_menu ${pxe_cfg_dir}/hosts/${pxe_host_menu}\n";

  }
  elsif ($action eq "del")
  {
    $mac = $MAC{$hn};
    $pxe_mac_link  = "01-${mac}" ; $pxe_mac_link =~ s/:/-/g ;

    $f = "${pxe_cfg_dir}/${pxe_mac_link}" ;
    if ( -f $f )
    {
      system("rm $f"); print " deleted pxe mac link $f\n";
    }

    $f = "${pxe_cfg_dir}/${pxe_mac_file}";
    if ( -f $f )
    {
      system("rm $f"); print " deleted pxe mac file $f\n";
    }

    $f = "${pxe_cfg_dir}/hosts/${pxe_host_menu}";
    if ( -f $f )
    {
      system("rm $f"); print " deleted pxe host menu $f\n";
    }

  }
  return(0);
}

# nsc add from filr

sub nsc_add_from_file # curently not used
{
  print "\nnot yet implented !: add clients from file $hostspec ...\n\n";
}

sub nsc_del
{
  my $ip;
  my $entry;
  my $hn = $hostspec; # $hostspec kann (darf) hier nur ein hostname sein
  my $dn = $fqdn ; $dn =~ s/^[^\.]+\.//; 
  my $changed_dhcp_config ;
  print "nsc_del:ip=$ip\n";
  print "nsc_del:hn=$hn\n";

  $hosts_file = $configdir . '/' . $class . '.' . $host_cfg . '.hosts' ;

  if (&del_from_hostlist($class,$host_cfg,$hn))
  {
    print " client $hn deleted from $hosts_file . \n";
    print " -------------------------------------\n";
    # del dhcp entry
    $changed_dhcp_config = &manage_dhcp_entrys("del",$hn,$mac,$ip,$client_type);
    if ( $EXEC && $NO_SERVICE_RESTART == 0 && $changed_dhcp_config == 1) {system("rcdhcpd restart");}

    # del pxe entry
    $retval = &manage_pxe_entrys("del",$mac,$ip,$hn,$dn,$client_type);

    # del dlc root dir #  obsolete ab diskless-0.4.3
    #$retval = &manage_dlc_root("del",$dlc_base,$hn,$ip,$client_type); 
  }
  else
  {
     print "\n$hn not found in $hosts_file\n";
  }
}

sub nsc_query_OLD
{
  my $hn ;
  my $mac,$alu;$ip;$group;

  &myprint("\nquery $client_type client list...\n\n");
  if ($class eq "newsim")
  {
    for $hn (@HOSTS) { print "$hn mac=$MAC{$hn} alu=$ALU{$hn} \n"; }
  }
  elsif ($class eq "dlcXXX" || $class eq "sol" || $class eq "newsas")
  {
    for $hn (@HOSTS) { print "$hn mac=$MAC{$hn} ip=$IP{$hn}\n"; }
  }
  elsif ($client_type eq "rose")
  {
    for $hn (@HOSTS) { print "$hn mac=$MAC{$hn} group=$GROUP{$hn}\n"; }
  }

}

sub nsc_query
{
  my $hn ;
  my $string; 
  my @VARS=();
  my @VALUES=();
  my $sep=':';
  my $var;
  my $val;
  my $mac,$alu,$ip,$group,$resource_fqdn;
  my $l;

  &myprint("\nquery $client_type client list...\n\n");
  if ($opt_arg ne "")
  {
    @VARS = split(/[\s:;,\.\|\/\-\+\#]+/,$opt_arg);   
    # nimm erstes zeichen nach erster var als sep, oder leerzeichen wenn nur eine var
    $sep = $#VARS > 0 ? substr $opt_arg, length($VARS[0]),1 : ' ' ;  
    myprint "length(VARS[0])=". length($VARS[0])."\n";
    myprint "sep=\"$sep\"\n";
    myprint "VARS=\"$#VARS\"\n";
  }


  for $hn (@HOSTS)
  {
    $string = "";
    $mac=$MAC{$hn};$alu=$ALU{$hn};$ip=$IP{$hn};$group=$GROUP{$hn};$resource_fqdn=$RESOURCE_FQDN{$hn};
    for $var (@VARS) 
    {
      $_ = $var;
      /mac/   && do { $string .= $sep.$mac};
      /ip/    && do { $string .= $sep.$ip};
      /alu/   && do { $string .= $sep.$alu};
      /group/ && do { $string .= $sep.$group};
      /resource_fqdn/ && do { $string .= $sep.$resource_fqdn};
    } 
    print $hn.$string."\n"; 
  }

}

## nsc rebuild 

sub nsc_rebuild
{
  my $hn ;
  my $mac;
  my $ip;
  my $dn;
  my $fqdn;
  my $changed_dhcp_config ;

  ($server_ip,$server_fqdn) = &get_ip("is01");
  $dn = $server_fqdn ; $dn =~ s/^[^\.]+\.//;

  for $hn (@HOSTS)
  {
    print " -------------------------------------\n";

    $ip = $IP{$hn};
    $mac = $MAC{$hn};

    # add pxe entry
    if ($action eq "rebuild_pxe" || $action eq "rebuild_all")
    {
      $retval = &manage_pxe_entrys("del",$mac,$ip,$hn,$dn,$client_type);
      $retval = &manage_pxe_entrys("add",$mac,$ip,$hn,$dn,$client_type);
    }

    # add dhcp entry
    if ($action eq "rebuild_dhcp" || $action eq "rebuild_all")
    {
      $changed_dhcp_config = &manage_dhcp_entrys("del",$hn,$mac,$ip,$client_type);
      $changed_dhcp_config = &manage_dhcp_entrys("add",$hn,$mac,$ip,$client_type);
    }

    # add dlc root dir (for rebuild_all only)
    #if ($action eq "rebuild_root" || $action eq "rebuild_all")
    #{
    #  #$retval = &manage_dlc_root("del",$dlc_base,$hn,$ip,$client_type);
    #  $retval = &manage_dlc_root("add",$dlc_base,$hn,$ip,$client_type);
    #}
  }

   print "$hn mac=$MAC{$hn} ip=$IP{$hn}\n";
   if ( $EXEC && $NO_SERVICE_RESTART == 0 && $changed_dhcp_config == 1 ) {system("rcdhcpd restart");}
}

sub nsc_wol
{
  my $hn ;
  my $mac;
  my $ip;
  my $bc;
  my $cmd;

  for $hn (@HOSTS_SELECTED)
  {
    #print " waking up $hn ..\n";
    if ( ! defined $MAC{$hn})
    {
      print "  no mac address known for host $hn\n";
      next;
    }

    $mac = $MAC{$hn};
    $ip = $IP{$hn};
    $bc = $ip;
    $bc =~ s/(.*)\.(.*)\.(.*)\.(.*)/$1.$2.$3.255/ ;
    $cmd = "wol -i $bc $mac";
    rcmd("$cmd","localhost","0","print");
    #rcmd("$cmd",$host,$exec_opt,$print_cmd);
  }


  if ($NAGIOS_DOWNTIME_HANDLING)
  {
    for $hn (@HOSTS_SELECTED)
    {
      &nagios_downtime("reset",$hn)
    }
  }

}

sub nagios_downtime
{

# set and check nagios settings for downtime

  my $dt_cmd = shift; # possible commands: set / reset / list
  my $hn = shift;
  my $host = $hn; $host =~ s/\..*//; # get short hostname (as configured in nagios YET !)
  my $h;
  my $duration = $nagios_default_down_time;
  my $cmd_string;
  my $time; 
  my ($start_time, $local_start_time, $local_st);
  my ($end_time, $local_end_time, $local_et);
  my $downtime_id="";
  my $dt_id="";
  my $downtime_scheduled=0;
  my $line;
  my $next_line;
  my ($s_sec,$s_min,$s_hour,$s_mday,$s_mon,$s_year,$s_wday,$s_yday,$s_isdst);
  my ($e_sec,$e_min,$e_hour,$e_mday,$e_mon,$e_year,$e_wday,$e_yday,$e_isdst);

  if ( ! $nagios_downtime_setting_enabled ) {
    if ( -f $nagios_cfg_file ) {
      if (open(F,$nagios_cfg_file)) {
        @NAGIOS_CFG_FILe = <F>; close F;
        $nagios_status_file = (split(/=/,(grep(/^status_file/,@NAGIOS_CFG_FILe))[0]))[1];
        chomp $nagios_status_file;
        if (length($nagios_status_file) > 0 && -f $nagios_status_file) {
          #print "nagios_status_file=$nagios_status_file\n";
          $nagios_command_file = (split(/=/,(grep(/^command_file/,@NAGIOS_CFG_FILe))[0]))[1];
          chomp $nagios_command_file;
          if (length($nagios_command_file) > 0 && -p $nagios_command_file) {
            #&myprint("nagios_command_file=$nagios_command_file\n");
            &myprint("---------------------------------\n");
            &myprint("nagios downtime setting enabled !\n");
            #&myprint("nagios status file will be read !\n");
            &myprint("---------------------------------\n");
            $nagios_downtime_setting_enabled = 1;
            # read nagios status file and save in HASH
            if (open(F,$nagios_status_file)) {
              while($line = <F>){
                if ( $line =~ /^hostdowntime/) {
                  $line = <F>; chomp $line;
                  $h = (split /=/,$line)[1];
                  while( ($line = <F>) !~ /\}/) {
                    chomp $line;
                    ($key,$val) = split /=/,$line;
                    $key =~ s/\s+//;
                    $NAGIOS_HOSTDOWNTIME{$h}{$key} = $val;
                  }
                }
              } 
            } else { &myprint("WARNING: can't open nagios_status_file \"$nagios_status_file\" !\n"); }
          } else { &myprint("WARNING: nagios_command_file \"$nagios_command_file\" doesn't exist, is no named pipe or is an empty string\n"); }
        } else { &myprint("WARNING: nagios_status_file \"$nagios_status_file\" doesn't exist or is an empty string\n"); }
      } else { &myprint("WARNING: can't open $nagios_cfg_file \n"); }
    } else { &myprint("WARNING: $nagios_cfg_file not found\n"); }
  }


  $time = time();

  if ($dt_cmd eq "set") {
    $start_time = $time + $nagios_delay;
    $end_time = $start_time + $duration;
    &myprint("Setting Downtime for host $host: start_time = $start_time\tend_time = $end_time\n");
    $cmd_string = "[$time] SCHEDULE_HOST_DOWNTIME;$host;$start_time;$end_time;$nagios_fixed;0;$duration;$nagios_comment_author;$nagios_comment_data";
    &myprint($cmd_string."\n");
    if (open(F,">$nagios_command_file")) { print F $cmd_string ; close F; }
    select(undef, undef, undef, $nagios_sleep ); # wait $nagios_sleep sec 
  }
  elsif ($dt_cmd eq "reset" or $dt_cmd eq "list" ) {
    $dt_id = $NAGIOS_HOSTDOWNTIME{$host}{downtime_id};
    $start_time = $NAGIOS_HOSTDOWNTIME{$host}{start_time};
    $end_time = $NAGIOS_HOSTDOWNTIME{$host}{end_time};
    #($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($start_time);
    ($s_sec,$s_min,$s_hour,$s_mday,$s_mon,$s_year,$s_wday,$s_yday,$s_isdst) = localtime($start_time);
    ($e_sec,$e_min,$e_hour,$e_mday,$e_mon,$e_year,$e_wday,$e_yday,$e_isdst) = localtime($end_time);
    if ($dt_id != "") {
      if ($dt_cmd eq "reset" ) {
        $cmd_string = "[$time] DEL_HOST_DOWNTIME;$dt_id}\n";
        if (open(F,">$nagios_command_file")) { 
          &myprint("Resetting downtime ID=$dt_id for host $host\n"); 
          print F $cmd_string ; close F; 
          select(undef, undef, undef, $nagios_sleep ); # wait $nagios_sleep sec
          &myprint("Deleted !\n"); 
        } else { &myprint("writing to $nagios_command_file failed !!\n");}
      } elsif ($dt_cmd eq "list" ) { 
        printf ("Downtime for %s: %02i.%02i.%04i %02i:%02i:%02i - %02i.%02i.%04i %02i:%02i:%02i \n", $host,$s_mday,$s_mon+1,$s_year+1900,$s_hour,$s_min,$s_sec,$e_mday,$e_mon+1,$e_year+1900,$e_hour,$e_min,$e_sec);
      }
    } else {&myprint("no downtime for $host\n");}
  }
}

sub nsc_downtime
{
  #&myprint("$cmd Downtime for selected hosts:\n");
  for $hn (@HOSTS_SELECTED) { 
    &nagios_downtime($cmd,$hn)
  }
}

sub nsc_sysrq
{
  my $pwd=newsim;
  my $port=4094;
  my $expect_lines;

  for $hn (@HOSTS_SELECTED)
  {
	$expect_lines = <<"--------EXPECT";
	/usr/bin/expect <<-EOF
	spawn telnet $hn $port
	expect "sysrqd password: "
	send "$pwd\\n"
	expect "sysrq> "
	send "$cmd\\n"
	expect "sysrq> "
	EOF
--------EXPECT

	$expect_lines =~ s/	//g;
	print $expect_lines;
	print "----------------------------------------------\n";
	system($expect_lines); 
  }

}

## run commands on remote hosts

sub nsc_sh
{ 
    &run_on_host_list($cmd,\@HOSTS_SELECTED,$EXEC_OPT,"0");
}

sub nsc_shutdown
{ 
  &run_on_host_list("halt",\@HOSTS_SELECTED,$EXEC_OPT,"0");
    
  if ($NAGIOS_DOWNTIME_HANDLING)
  {
    for $host (@HOSTS_SELECTED)
    {
      &nagios_downtime("set",$host);
    }
  }
}

sub nsc_mount_is
{ 
    &run_on_host_list($cmd_mount_is,\@HOSTS_SELECTED,$EXEC_OPT,"0");
}
#### run a command remote on a list of hosts ###############

sub run_on_host_list
{ 
   my $cmd 	 = shift;
   my $HOSTS     = shift;
   my $exec_opt  = shift;
   my $print_cmd = shift;
   my $host;

   for $host (@$HOSTS)
   {
     #rcmd("$cmd",$host,"0","printonly");
     #rcmd("$cmd",$host,"0","0");
     print "------------------ [$host] -------------------------------\n" if $SEPLINES ;
     rcmd("$cmd",$host,$exec_opt,$print_cmd);
   }
}
sub nsc_rsync
{ 
  my $host;
  my $cmd;

  #$rsync_opt = '--dry-run' if $rsync_opt =~ /(dry|test|check)/ ;
  
  for $host (@HOSTS_SELECTED)
  {
     rsync($rsync_from,"$host:$rsync_to","out+err","print",$rsync_opt);
     #$cmd = "rsync -ahHv $rsync_opt $rsync_from $host:$rsync_to";
     #print "$cmd\n";
     #system($cmd);
  }
}

########## create_system_hostlist #######
sub create_system_hostfile
{
  # used pxe_client_config_dir instaed and defined global
  #my $client_config_dir = "/srv/inst/xchg/client/config";
   my $system_hosts_file = $configdir . "/system.all.hosts";
   my @SYS_HOSTS = ();
   my @SYS_HOSTS_CURRENT = ();
   my @VARS = (); 
   my ($dummy, $mac, $line,$parms);
   my $current_exists = 0;
   my $needs_update = 0;
   my $TMP; 
   my $ret;
   my $sub_return = 0;

   if ( -f $system_hosts_file ) 
   { 
     open(SYS_HOSTS,"$system_hosts_file") || die "can't open $system_hosts_file ";
     @SYS_HOSTS_CURRENT = <SYS_HOSTS>; ; 
     chomp @SYS_HOSTS_CURRENT;
     close SYS_HOSTS;
     $current_exists = 1;
   }
   else
   {
     print "no system.all.hosts found.\n";
     $current_exists = 0;
   }
   
   # Liste aus laufenden vms erstellen wenn Option USE_VM_LIST gesetzt

   my %list_cmd={};
   $list_cmd{"xen"}="xm list";
   my @VM_LIST_OUT_TMP=();
   my @VM_LIST_OUT=();
   my @RUNNING_VMS=(); 
   my @LINE=();

   if ($USE_VM_LIST)
   {
     @VM_LIST_OUT_TMP=`$list_cmd{"xen"}`;
     @VM_LIST_OUT=grep(/nsi/,@VM_LIST_OUT_TMP);
     @LINE=();
     @RUNNING_VMS=();

     for $line (@VM_LIST_OUT)
     {
       chomp $line;
       @LINE=split(/\s+/, $line);
       if ($#LINE >=5) { push(@RUNNING_VMS,$LINE[0]."\n") ;}
     }

     #for $vm (@RUNNING_VMS)
     #{
     #  print "$vm is running\n";
     #}
     $needs_update = 1;
     $only_running_vms = 1;
     @SYS_HOSTS = @RUNNING_VMS;
     #@SYS_HOSTS_CURRENT = ();
   }
   else
   {

     # quick'n dirty mac aus 2step.vars lesen 
     
     my @X={};
     my $vm;
     my $only_running_vms = 0; 
  
     while(<$pxe_client_config_dir/*.de>)
     {
        $TMP = $_;
        $vars_file = $_ . "/2step.vars";
        if ( -f $vars_file )
        {
          open(VARS,$vars_file);
          @VARS = <VARS>;
          close @VARS; 
          $line = (grep(/^dm=/,@VARS))[0];
          chomp $line;
          ($dummy,$mac) = split(/=/,$line);
          $mac =~ s/["']//g;
          $parms = $mac ne "" ? "mac=".$mac : "" ;  # add mac to line when found
        }
        else
        {
          print " WARNING: $vars_file not found. Possible INSTALL ERROR !!\n"
        }
  
        $_ = $TMP;
        s/.*\///;
        chomp;
        #print SYS_HOSTS $_ . "\n" ; 
        push(@SYS_HOSTS,$_." ".$parms."\n");
     }
   }

   if ( $#SYS_HOSTS >= 0 ) 
   { 
     if ($current_exists == 1)
     {
       if ($#SYS_HOSTS_CURRENT < $#SYS_HOSTS || $only_running_vms == 1)
       {
         &myprint(" WARNING: found more installed hosts than in current system hostlist, will add..\n"); 
         $needs_update = 1;
       }
       elsif ($#SYS_HOSTS_CURRENT > $#SYS_HOSTS)
       {
         &myprint(" WARNING: found more hosts in current system hostlist, than due to install data or running vms!!.\n"); 
         &myprint("          Will make NO changes !!\n"); 
       }
     }

     if (  ! $current_exists || $needs_update && $HOSTLIST_CONSISTENCY_UPDATE_ENABLED )
     {
       &myprint(" INFO: Updating/creating system hosts file...\n");
       open(SYS_HOSTS,">$system_hosts_file") || die "can't open $system_hosts_file ";
       print SYS_HOSTS @SYS_HOSTS  ; 
       close SYS_HOSTS;
       $sub_return = 1;
     }
   }
   else
   {
     if ($current_exists == 0)
     {
       &myprint( " WARNING:\n");
       &myprint(" no system hosts file or install data found !\n>>> Please install ALL clients first before using this command !!! <<<\n"); 
       &myprint(" If install data is only deleted, create $system_hosts_file manually !! <<<\n"); 
       exit(1);
     }
     &myprint("\n WARNING !! No INSTALL DATA found. Maybe deleted. Using existing system hostlist !!!\n\n");
   }
   return $sub_return;

}
########## add to hostlist  ################

sub add_to_hostlist # $class,$host_cfg,$hostspec,$mac,$dlc_root # dlc_root=opt_arg
{  
   my $class = shift;   
   my $host_cfg = shift;   
   my $host = shift;
   my $mac = shift;
   my $client_type = shift;
   my $opt_arg = shift;
   #my $dlc_root = shift;
   my (@opts,$pair,$parm,$val,$query,$ip);
   my $group = "";
   my $PARM;
   my $retval;
   my $lockfile;
   my $host_file_entry;
   my $add2line = "";
   my $alu = "";
  

  # must be possible for all client_types
  #if ($client_type ne "dlc" && $client_type ne "sol" && $client_type ne "newsas" ) {print " add_to_hostlist: no task for client type $client_type\n"; return(3);}

   $hosts_file = $configdir . '/' . $class . '.' . $host_cfg . '.hosts' ; 
   $lockfile = $hosts_file.".lock";
   
   if ($client_type eq "dlc" && $opt_arg ne "")
   { $dlc_root = $opt_arg; $host_file_entry = "$host\tmac=$mac dlc_root=$dlc_root\n" } 
   elsif ($client_type eq "rnsc")
   { $host_file_entry = "$host mac=$mac $opt_arg\n" }
   elsif ($client_type eq "nsc")
   { 
     $_ = $host;
     if (/^cwp/) {$alu = "trainee"};
     if (/^adc/) {$alu = "trainee"};
     if (/^psp/) {$alu = "pilot"};

     if ($alu ne "") 
     {$add2line = "alu=$alu $opt_arg"}
     else
     {$add2line = "$opt_arg"}

     $host_file_entry = "$host mac=$mac $add2line\n";
   }
   else
   { $host_file_entry = "$host mac=$mac\n" } 

   if (defined $MAC{$host} && defined $MAC_HOSTS{$mac}) 
   {
      if ($MAC_HOSTS{$mac} eq $host) {$retval = -1;}  # entry is already made
      else { print "warn -1: found $host with mac $mac\n"; $retval = 1;}
   }
   #elsif (defined $MAC_HOSTS{$mac}) {print "err 2: found $MAC_HOSTS{$mac} with mac $mac\n" ; $retval = 2;}
   # TODO: test !!
   else
   {
     $retval = 0;

     if (defined $MAC_HOSTS{$mac})
     {
       print "warn -3: found $MAC_HOSTS{$mac} with mac $mac\n" ; $retval = -3;
       &del_from_hostlist($class,$host_cfg,$MAC_HOSTS{$mac})
     }

     if (defined $MAC{$host}) 
     {
       print "warn -2: found $host with mac $MAC{$host}\n" ; $retval = -2;
       &del_from_hostlist($class,$host_cfg,$host)
     }

     while (-f $lockfile) 
     {
        print " add_to_hostlist: waiting for $lockfile to be deleted ...\n" ;
        system("sleep 1");
     }
     system("touch $lockfile");
     open(HOSTS_FILE,">>$hosts_file") || die "can t open $hosts_file";
      
     print HOSTS_FILE $host_file_entry;
     close HOSTS_FILE;
     system("rm $lockfile");

   }
   return $retval ;
}

########## delete from host list ################

sub del_from_hostlist # $class,$host_cfg,$hostspec
{  
   my $class = shift;   
   my $host_cfg = shift;   
   my $host = shift;
   my $retval =0;
   my @HOSTS;
   my $lockfile;
   #my @HOSTS_OUT;

   $hosts_file = $configdir . '/' . $class . '.' . $host_cfg . '.hosts' ; 
   $lockfile = $hosts_file.".lock";
   system("cp $hosts_file $hosts_file.$$");
 
   while (-f $lockfile) 
   {
      print " del_from_hostlist: waiting for $lockfile to be deleted ...\n" ;
      system("sleep 1");
   }
   system("touch $lockfile");

   open(H,$hosts_file) || die "cant open $hosts_file for reading";
   @HOSTS = <H>;
   close H;

   open(H,">$hosts_file") || die "cant open $hosts_file for writing";

   for(@HOSTS)
   {
     if (/^$host/) {$retval = 1; next}
     print H ;
   } 
   close H;

   system("rm $lockfile");

   return $retval;      
}

########## uptdate hostlist entry (not yet used, under development !!) ################

sub update_hostlist_entry # $class,$host_cfg,$hostspec
{  
   my $class = shift;   
   my $host_cfg = shift;   
   my $host = shift;
   my $retval =0;
   my @HOSTS;
   my $lockfile;
   #my @HOSTS_OUT;

   $hosts_file = $configdir . '/' . $class . '.' . $host_cfg . '.hosts' ; 
   $lockfile = $hosts_file.".lock";
   system("cp $hosts_file $hosts_file.$$");
 
   while (-f $lockfile) 
   {
      print " del_from_hostlist: waiting for $lockfile to be deleted ...\n" ;
      system("sleep 1");
   }
   system("touch $lockfile");

   open(H,$hosts_file) || die "cant open $hosts_file for reading";
   @HOSTS = <H>;
   close H;

   open(H,">$hosts_file") || die "cant open $hosts_file for writing";

   for(@HOSTS)
   {
# HIER update funktion einbauen !!
#     if (/^$host/) {$retval = 1; next}
     print H ;
   } 
   close H;

   system("rm $lockfile");

   return $retval;      
}

########## get ip from hostname ################

sub get_ip
{
  my $host = shift;
  my $ip;
  my $fqdn;

  chomp ($query = qx(host $host)); 
  # nss.lx2.lgn.dfs.de has address 10.232.205.10
  $ip = (split(/\s+/,$query))[-1];
  $fqdn = (split(/\s+/,$query))[0];
  return ($ip,$fqdn);
}

########## get host list ################

sub get_host_lists
{  
   my $class = shift;   
   my $host_cfg = shift;   
   my $hostspec = shift;   
   my $mac;
   my $expand_hostspec = shift;
   my (@opts,$pair,$parm,$val,$query,$ip);
   my @HOSTS_SELECTED_TMP;
   my $run = ''; 
   my $host = "";
   my $group = "";
   my $system_hostfile=$configdir . '/' . 'system.all.hosts';
   my $newsim_hostfile=$configdir . '/' . 'newsim.all.hosts';
   my $rose_hostfile=$configdir . '/' . 'rose.all.hosts';
   my $rnsc_hostfile=$configdir . '/' . 'rnsc.all.hosts'; # for remote piloting
   my $PARM;
   my $needs_update = 0;

   #if ($class eq "system") { &create_system_hostfile;}
   $needs_update = &create_system_hostfile;
   $hosts_file = $configdir . '/' . $class . '.' . $host_cfg . '.hosts' ; 

   # creating initial newsim hostlist if not found


   if ( ! -f $newsim_hostfile || $needs_update)
   {
     #&create_system_hostfile;
     open(H,$system_hostfile) || die "can't open $system_hostfile";
     open(NEWSIM_HOSTFILE,">$newsim_hostfile") || die "can't open $newsim_hostfile";
     while(<H>)
     {
       next if /^#/;
       next if /^$/;
       last if /#<end>/;
       chomp;
       s/^cwp.*/$& alu=trainee/; 
       s/^adc.*/$& alu=trainee/; 
       s/^psp.*/$& alu=pilot/; 
       print NEWSIM_HOSTFILE $_ . "\n"; 
     }
     close H;
     close NEWSIM_HOSTFILE;

     if ($needs_update ) { print " INFO: $newsim_hostfile has been UPDATED !\n";}
     else
     { print " INFO: INITIAL $newsim_hostfile. CREATED. Check and edit if necessary !!! ...\n";}
   }

   # creating initial rose hostlist if not found

   if ( ! -f $rose_hostfile || $needs_update)
   {
     #&create_system_hostfile;
     open(H,$system_hostfile) || die "can't open $system_hostfile";
     open(ROSE_HOSTFILE,">$rose_hostfile") || die "can't open $rose_hostfile";
     while(<H>)
     {
       next if /^#/;
       next if /^$/;
       last if /#<end>/;
       chomp;
       s/.*/$& group=1/; 
       s/^cwp1-s1.*/$& group=1 run=run_1/; 
       print ROSE_HOSTFILE $_ . "\n"; 
     }
     close H;
     close ROSE_HOSTFILE;

     if ($needs_update ) { print " INFO: $rose_hostfile. has been UPDATED !\n";}
     else
     {
       print "\n INFO: INITIAL $rose_hostfile CREATED !\n";
       print " CWP1-S1 is Master, all others are slaves !!!\n";
     }
     print " Check and edit if necessary !!! ...\n\n";
   }

   # creating initial emtpy rnsc hostlist if not found (to avoid error message when not found)

   if ( ! -f $rnsc_hostfile ) { system("touch $rnsc_hostfile"); }

   if (! -f $hosts_file ) { print "$hosts_file not found\n" ; return 0;};

   &myprint("loading hosts file $hosts_file\n")  ; 
   
   open(H,$hosts_file) || die "can't open $hosts_file";
   
   while(<H>)
   {
     $line = $_;
     next if /^#/;
     next if /^$/;
     last if /#<end>/;
     chomp;
      
     ($host,@opts) = split;
     # get vars from hosts file  
## todo:  AENDERN !!!
     for $pair (@opts)
     {
       ($parm,$val) = split(/\s*=\s*/,$pair);
        my $PARM = uc($parm);
        $$PARM{$host} = $val ;   # funzt nur ohne use strict !!!
        #print "debug: PARM=$PARM val=$val \n";
        push(@PARMS,$PARM);
     }

     ($ip,$fqdn) = &get_ip($host);
     $IP{$host} = $ip ;

     # use group defintion from config file or 
     # hosttype (cwp,psp etc) as 'group' if group is not defined 

     if (defined $GROUP{$host}) {$group = $GROUP{$host}; push(@GROUPS,$group);}
     else                       {$group = substr($host,0,3); push(@GROUPS,$group);} 
     $run = $RUN{$host};
     push(@HOSTS,$host); 

     #debug
     #print "inside: get_host_lists: MAC{host} = $MAC{$host} \n";

     if (defined $MAC{$host}) 
     {
       $mac = $MAC{$host};
       $MAC_HOSTS{$mac} = $host;
     }

     if ( $run ne '' ) 
     {
        $MODE{$host} = 'master';
        push(@MASTERS_ALL,$host);
        $MASTER_IP{$group}   = $ip;
        $MASTER_HOST{$group} = $host;
        #push(@GROUPS,$group);
     }
     else
     {
        $MODE{$host} = 'slave';
        push(@{$SLAVE_HOSTS{$group}},$host);
        push(@SLAVES_ALL,$host);
     }
     #defined $group && print "$host is $MODE{$host} of group $group\n";
     #defined $run && print "  run = $run \n" , '-'x40 , "\n";
   }
   close H;
 

   print "##################################\n" if $PRINT_COMMENTS;

   #### process selected groups and/or hostspec ##################################
   
   # uniq GROUPS

   @GROUPS_TMP = @GROUPS ;
   undef %saw;
   @GROUPS = grep(!$saw{$_}++, @GROUPS_TMP);

   if ( $use_groups ) 
   {
     if ( $groups_selected eq "" || $groups_selected eq "all" ) 
     {
       $groups_selected = "all";
       print "selected group(s) = all \n";
       @GROUPS_SELECTED = @GROUPS;
     }
     else
     {
       print "selected group(s) = $groups_selected \n";
       @GROUPS_SELECTED = split(/\,/,$groups_selected);
     }
     for $group (@GROUPS_SELECTED)
     {
       print "group=$group \n";
       if (grep(/$group/,@GROUPS))
       {
         print "MASTER_HOST($group) = $MASTER_HOST{$group}\n"; ; 
         push(@MASTERS,$MASTER_HOST{$group}) if defined $MASTER_HOST{$group}; 
         for $host (@{$SLAVE_HOSTS{$group}})
         {
           print "	    slave host = $host\n";
           push(@SLAVES,$host);
         }
       }
       else { print "group $group is NOT DEFINED!!\n"; }
     }
     @HOSTS_SELECTED_TMP = (@MASTERS,@SLAVES);
   }
   elsif ( $hostspec ne "" )
   {
     &myprint("hostspec = $hostspec \n");
     if ($hostspec eq "all") { $hostspec = "." };
     @SPECS = split(/\,/,$hostspec);
     for $spec (@SPECS)
     { 
       @GREP = grep(/$spec/,@HOSTS);
       @HOSTS_SELECTED_TMP = (@HOSTS_SELECTED_TMP,@GREP); 
     }
   }
   else {@MASTERS = @MASTERS_ALL; @SLAVES = @SLAVES_ALL ; @HOSTS_SELECTED_TMP = @HOSTS;}
 
   # for add delete comands (-a -d)
   &myprint("expand_hostspec = $expand_hostspec \n");
   if ($expand_hostspec eq "no") {push(@HOSTS_SELECTED_TMP,$hostspec);}
 
   #todo: sort hosts to put sup hosts at the end of the list
 
   if ( (@HOSTS_SELECTED_TMP) == () ) { print "NO MASTERS OR SLAVES SELECTED!! exiting ... \n"; exit(1); }
   if ( $host_check_enabled ) 
   {
      #@HOSTS_SELECTED = &check_hosts(@HOSTS_SELECTED_TMP); 
     print STDERR "checking hosts and if they are reachable ...\n\n" if $PRINT_ERR;
   
     for $host (@HOSTS_SELECTED_TMP)
     {
   	#@PING_RESULT=`ping $host -n 1 -m 2`; # HP-UX
   	#@PING_RESULT=`ping $host -w 1 `;     # Linux
   	#@PING_RESULT=`ping $host 1`;         # Solaris
   
   	@PING_RESULT=`ping $host -c 1 -W 2`;  # Linux 2
   
   	PING:
   	{
   
           if ((grep(/0 .*received/,@PING_RESULT))[0] ne "" ) {$status = "not_reached"; last PING;}; # Linux
           if ((grep(/1 .*received/,@PING_RESULT))[0] ne "" ) {$status = "ok"; last PING;};          # Linux
   
   	#if ((grep(/no answer/,@PING_RESULT))[0] ne "" ) {$status = "not_reached"; last PING;}; # HP-UX
   	#if ((grep(/is alive/,@PING_RESULT))[0] ne "" ) {$status = "ok"; last PING;};           # HP-UX
   
   	$status = "ping_error";
   	}
   
   	print STDERR "checking $host :... " if $PRINT_ERR;
   	$_ = $status;
   	SWITCH:
   	{
   	   /ok/ && do { push(@HOSTS_SELECTED,$host); 
   
   			  print STDERR "reached, ok\n" if $PRINT_ERR;
   			  $i++;
   			  last SWITCH;
   			};
   	   /not_found/ && do { print STDERR " $host (or corrected) not found in /etc/hosts\n" ; last SWITCH; };
   	   /not_reached/ && do { print STDERR "  $checked_host could not be reached !!\n" ; last SWITCH; } ;
   	   /ping_error/ && do { print STDERR " ping command error !! \n" ; last SWITCH; } ;
   	}
     }
   }
   else                       
   {@HOSTS_SELECTED = @HOSTS_SELECTED_TMP;}
   
   # remove hosts from list which have been addressed via ccmdline arg  exclude=<regexp>

   for (@EXCLUDED_HOSTS)
   {
     $excluded_host = $_;
     print "excluded: $excluded_host\n";
     @TMP = grep(!/$excluded_host/,@HOSTS_SELECTED);
     @HOSTS_SELECTED = @TMP;
   }

   return 1;
}

#### load run file ################
   
sub load_run_file
{
   my $class = shift;
   my $host_cfg = shift;   
   my $openret;
   my $runload_file = $configdir . '/' . $class . '.' . $host_cfg . '.runload' ;

   $openret = open(F,$runload_file) ;
   if ($openret != 1 && $class eq "rose") {print "warning: can't open $runload_file !\n"; return;}
   
   while(<F>)
   {
     next if /^#/;
     next if /^$/;
     chomp;
     my ($run,$runfile) = split(/\s*=\s*/);
     $RUNFILE{$run} = $runfile; 
   }
   close F;
}

#### nsc init ######################

sub nsc_init
{
   my $host;
   print "initialize newsim..\n";

   print "clean up processes (simkill all)..\n";
   for $host (@HOSTS_SELECTED)
   {
     rcmd("pkill -f rose.exe",$host,"0","0");
     rcmd($cmd_kill_newsim,$host,"0","0");
   }

   print "\n--->>> configuring autologin .. <<<---\n\n";

   for $host (@HOSTS_SELECTED)
   {
     if (not defined $ALU{$host})
     { 
        print "WARNING: AUTOLOGIN USER for host $host IS NOT DEFINED in $hosts_file. Using defaults !!!\n\n"; 
       $_ = $host;
       $ALU{$host} = "trainee" if /^cwp.*/ ;
       $ALU{$host} = "trainee" if /^adc.*/ ;
       $ALU{$host} = "pilot" if /^psp.*/ ;
     }

     rcmd("config_autologin.sh $ALU{$host} on;rcxdm restart",$host,"0","0");
   }
   #--------------------------------------------------------------------------------------
   print("\nsleep $sleep{'xdm-restart'}\n\n"); system("sleep $sleep{'xdm-restart'}") if $EXEC;
   #--------------------------------------------------------------------------------------

   for $host (@HOSTS_SELECTED)
   {
     rcmd($cmd_init_atcoach,$host,"bg","print");
   }

   for $host (@HOSTS_SELECTED)
   {
     rcmd("$cmd_set_wall_msg newsim hostname",$host,"0","0");
   }

}

#### start newsim ###############

sub nsc_start
{
   print "\nnot yet implemented !!\n";
}

#### stop newsim ###############

sub nsc_stop
{
   print "\nnot yet implemented !!\n";
}

sub nsc_kill_x
{
   &run_on_host_list($cmd_kill_x,\@HOSTS_SELECTED,"out+err","1");
}

sub nsc_kill_newsim
{
   &run_on_host_list($cmd_kill_newsim,\@HOSTS_SELECTED,"out+err","1");
}

sub nsc_kill_vcs
{
   &run_on_host_list($cmd_kill_vcs,\@HOSTS_SELECTED,"out+err","1");
}

sub nsc_reboot
{
   my $host;

   print "simkill all on selected clients !!\n";
   &nsc_kill_newsim ;
   system("sleep 3");
   print "reboot selected newsim clients !!\n";
   for $host (@HOSTS_SELECTED) { rcmd("reboot",$host,"out+err","1"); }
}

#### set autologin ######################

sub nsc_autologin
{
   my $host;
   my $my_user;

   print "\n--->>> configure autologin .. <<<---\n\n";

   for $host (@HOSTS_SELECTED)
   {
     if (defined $user)
     {
        $my_user = $user;
     }
     elsif (defined $ALU{$host})
     {
	$my_user = $ALU{$host};
     }
     else { print "WARNING: AUTOLOGIN USER for host $host IS NOT DEFINED in $hosts_file  !!!\n\n"; }
     rcmd("config_autologin.sh $my_user $val;rcxdm restart",$host,"0","0");
   }
   if ( $val eq "on" )
   {
     print("\nsleep $sleep{'xdm-restart'}\n\n"); system("sleep $sleep{'xdm-restart'}") if $EXEC;

     for $host (@HOSTS_SELECTED)
     {
       rcmd("$cmd_set_wall_msg newsim hostname",$host,"0","0");
     }
   }
}

######################################

#### config  ###############

sub nsc_config
{
   my $host;
   my $option = 0;
   my $cmd ; 

   print "\n--->>> configure $val .. <<<---\n\n";

   $_ = $val;

   if (defined $cmd_config{$val} ) 
   {
     $cmd = $cmd_config{$val} ; 
     &run_on_host_list($cmd,\@HOSTS_SELECTED,$EXEC_OPT,"0");
   }
   else { print "option $val not known !! \n" ; exit(1) ; }

}

sub nsc_get_config
{
 # nach oben ?! #
 my @config_vals=("x11");
 # eigentlich auch nach obern, da mehrfach benutzt !!
 ($server_ip,$server_fqdn) = &get_ip("is01");
 $server_dn = $server_fqdn ; $server_dn =~ s/^[^\.]+\.//;
 #
 my $host;

 print "\n--->>> get $val config  <<<---\n\n";

 if ( ! grep(/$val/, @config_vals)) 
 { print "option $val not known !! \n" ; exit(1) ; }

 $_ = $val;

 /x11/ & do 
 {
   for $host (@HOSTS_SELECTED)
   {
     print "<<< get $val config for host $host in $server_dn >>>\n";
     system("mkdir -p ${x11_config_backup_dir}/${server_dn}/xorg_conf");
     system("mkdir -p ${x11_config_backup_dir}/${server_dn}/xinitrc");
     $cmd = "scp ${host}:/etc/X11/xorg.conf ${x11_config_backup_dir}/${server_dn}/xorg_conf/xorg.conf.${host}"; 
     print $cmd."\n";
     system($cmd);
     $cmd = "scp ${host}:/etc/X11/xinit/xinitrc ${x11_config_backup_dir}/${server_dn}/xinitrc/xinitrc.${host}"; 
     print $cmd."\n";
     system($cmd);
     $cmd = "scp ${host}:/etc/2step/x11.vars ${x11_config_backup_dir}/${server_dn}/x11.${host}.vars"; 
     print $cmd."\n";
     system($cmd);
   }
 }
}

sub nsc_uptime
{
   my $host;

   print "get uptime of cwp's and psp's !!\n";
   for $host (@HOSTS_SELECTED) { print "$host: "; rcmd("uptime",$host,"out+err","0"); }
}

# Variante mit temporaer modifiziertem PXE Menu 

sub nsc_install
{
  my $host;
  my $cmd;

  for $host (@HOSTS_SELECTED) 
  { 
    $install_flag_file = "/srv/inst/xchg/client/config/".$host."/install_on_boot" ;
    $cmd = "touch $install_flag_file";
    print "$cmd" . "\n";
    system($cmd);
    print "reboot $host for install .. \n";
    rcmd("reboot -find",$host,"bg","0"); 
  }
  
  system("$cmd_update_pxe_cfg"); # wertet die Flagfile aus und erzeugt pxe-menu fuer hosts
                                 # mit automatischer installation als default eintrag
                                 # loescht dann die Flagfiles wieder
  system("echo \"ksh $cmd_update_pxe_cfg\" | at now + 3 minutes"); #erzeugt nach 3 Minuten wieder das Default Menu
}

# Variante mit kexec 

sub nsc_install_kexec
{
  my $host;
  my $proc_cmdline_file ;
  my $proc_cmdline;
  my $fqdn ; 
  my $cmd ;
  my $arg;
  my $kernel ;
  my $initrd ;
  my %BOOTARGS = {};
  my $bootargs ;

  print "(re)install host !!\n\n";
  &nsc_mount_is ;

  for $host (@HOSTS_SELECTED) 
  { 
    print "install $host: \n"; 
    $fqdn = $host; 
    $proc_cmdline_file = "/srv/inst/xchg/client/config/".$host."/proc-cmdline" ;
    #$twostep_vars_file =  "/srv/inst/xchg/client/config/".$host."/2step.vars";


    if (open(F,$proc_cmdline_file) )
    {
      $proc_cmdline = <F> ; chomp $proc_cmdline ; 
      #print "proc_cmdline: $proc_cmdline \n";
      @PROC_CMDLINE = split(/\s+/,$proc_cmdline);
      
      for $arg (@PROC_CMDLINE)
      {
        ($var,$val) = split(/=/,$arg);
        $BOOTARGS{$var} = $val ;
      }
      
      $kernel = "/srv2/inst/tftpboot/" . $BOOTARGS{'BOOT_IMAGE'} ;
      $initrd = "/srv2/inst/tftpboot/" . $BOOTARGS{'initrd'} ;
      $bootargs = "";
      
      #for $var ('load_ramdisk','initrd','install','autoyast','kb','type','x11','dn','hn')
      for $var ('load_ramdisk','install','autoyast','kb','type','x11','dn','hn')
      {
        if ( $BOOTARGS{$var} ne "" )
        {
           print $var . "=" . $BOOTARGS{$var}  ."", "\n";
           $bootargs .= " " . $var . "=" . $BOOTARGS{$var} ;
        }
      }
      
      #print $bootargs , "\n" ;

      # Versuch 1: Direkt ausfuehren: funzt net !

      print "$cmd \n";
      #rcmd("$cmd",$host,"out+err","0"); 

      # Versuch 2: Script erzeugen, auf host kopiern und dann ausfuehren: funzt net

      $cmd =  "kexec -l $kernel --initrd=$initrd --append=\"$bootargs\" ; sleep 5 ; kexec -e";
      open(F,">/tmp/install.sh") || die "cant open /tmp/install.sh\n";
      print F $cmd."\n" ;
      close F;

      rcopy("/tmp/install.sh","$host:/tmp","0","0");
      #rcmd("sh /tmp/install.sh",$host,"out+err","0"); 

      # In beiden Faellen haengt sich kexec auf !!.... -> falsche Parms ?? 

    }
    else {print "$proc_cmdline_file NOT FOUND !!!\n" ;}
  }
}

#### manage sinatra / audiolan for rose ######

sub rose_audio
{
  &manage_rose_audio($cmd);
}

sub manage_rose_audio
{
  my $cmd        = shift;
  my $home       = "/nss/home/audiolan";
  my $bindir     = "${home}/bin" ;
  my $cfgdir     = "${home}/config" ;
  my $cmd_ext    = "";




  if ( -f $sinatra_start_script )
  {
    print "processing  sinatra $cmd \n";
    if    ( $cmd eq "start" )  
    { $cmd_sinstra = "su - spv -c '".$sinatra_start_script." ".${host_cfg}."'" ; }
    elsif ( $cmd eq "stop"  )
    { $cmd_sinstra = "su - spv -c '".$sinatra_stop_script." ".${host_cfg}."'" ; }
    else  
    { print "$cmd not known !!\n"; exit(1); }
    
    for $host (@MASTERS,@SLAVES) {rcmd($cmd_sinstra,$host,"0","0");}
  }
  elsif (  -d "${cfgdir}/${host_cfg}" )
  {
    if    ( $cmd eq "start" )  { $script = "StartAudiolan" ; }
    elsif ( $cmd eq "stop"  )  { $script = "StopAudiolan" ; }
    else                          { print "$cmd not known !!\n"; exit(1); }
  
    for $group (@GROUPS_SELECTED)
    {
      print "processing audio group $group \n";
  
      for $cfg (`ls -d ${cfgdir}/${host_cfg}/*[!0-9]${group}`)
      {
         chomp $cfg;
         $config = `basename $cfg`;
         rcmd("su - audiolan -c ". "'"."cd ${cfgdir} ; ${bindir}/$script ${host_cfg}/${config}"."'","sup1-s1","0","0");
      }
    }
  }
  else
  {
      print "Neither sinatra start/stop script $sinatra_start_script nor ausiolan config ${cfgdir}/${host_cfg} found. Skipping audio !!!\n";
      return 1 ;
  }

}

#### init rose ###############

sub rose_init
{
   my ($host,$run,$ip,$group,$runfile,$runpath,$Exercise,$LoadRun);
   my ($config_ini_local,$tcpip_ini_local);
   my ($master_host,$master_ip);

   if ( ! -f $config_ini_tpl ) { print "\n\n!!! $config_ini_tpl NOT FOUND !!! exiting ...\n\n"; exit(1) } 


   print "clean up and set autologin ...\n";

   for $host (@MASTERS,@SLAVES)
   {
     rcmd("pkill -f atcoach",$host,"0","0");

     # stop wine 
     rcmd($cmd_stop_rose,$host,"0","0","0");

     # stop remaining rose process(es)
     rcmd("pkill rose.exe",$host,"0","0","0");

     # set autologin and restart xdm
     rcmd("config_autologin.sh rose on;rcxdm restart",$host,"0","0");
   }

   print("\nsleep $sleep{'xdm-restart'}\n\n"); system("sleep $sleep{'xdm-restart'}") if $EXEC;

   #### loop masters ###################################

   print "\nMASTERS: process ini files for rose ..\n\n";
   
   for $host (@MASTERS)
   {
     $run      = $RUN{$host};
     $ip       = $IP{$host};
     $group    = $GROUP{$host};
     $runfile  = defined $RUNFILE{$run} ? $RUNFILE{$run} : "";
     print "$host: $ip $group  run=\"$run\"  p=\"$runpath\"  f=\"$runfile\"\n" if $PRINT_CMD ;
     $runpath  = dirname($runfile) ;
     $Exercise = 'Exercise = ' . $runpath;
     $LoadRun  = 'LoadRun = ' . $runfile;
     $config_ini_local = "$cfg_tmp_dir/" . "config.ini." . $host;

     system("cp -p $config_ini_tpl $config_ini_local"); 
   
     if ($runfile ne "")
     {
       open(INI,">>$config_ini_local") || die "can't open $config_ini_local";
       print INI "$Exercise\r\n";
       print INI "$LoadRun\r\n";
       close INI;
     }
  
     # remove tcpip.ini
   
     rcmd("test -f $tcpip_ini && rm $tcpip_ini",$host,"0","0");

     # create config.ini
   
     rcopy($config_ini_local,"$host:$config_ini","0","0");
     rcmd("chown rose:rose $config_ini",$host,"0","0");

     rcmd("$cmd_set_wall_msg rose ready",$host,"0","0"); 
   }

   ########################################################
   
   if ($SLAVES[0] eq "" ) { print "\n\nno slaves -> exiting..\n\n\n"; exit(0);}
    
   #### loop slaves  ###################################
   
   print "\nSLAVES: process ini files for rose ..\n\n";
   
   for $host (@SLAVES)
   {
     $group       = $GROUP{$host};
     $master_host = $MASTER_HOST{$group};
     $master_ip   = $MASTER_IP{$group};
     $tcpip_ini_local = "$cfg_tmp_dir/" . "tcpip.ini." . $host;

     print "-----------------------------------------------------------------\n" if $PRINT_CMD;
     print "$host: group=$group master_host=$master_host master_ip=$master_ip \n" if $PRINT_CMD;
   
     # clean config.ini

     rcopy($config_ini_tpl,"$host:$config_ini","0","0");
     rcmd("chown rose:rose $config_ini",$host,"0","0");
   
     # create tcpip_ini
   
     open(INI,">$tcpip_ini_local") || die "can't open $tcpip_ini_local"; 
     print INI "$master_ip\r\n";
     close INI;

     rcopy($tcpip_ini_local,"$host:$tcpip_ini","0","0");
     rcmd("chown rose:rose $tcpip_ini",$host,"0","0");

     rcmd("$cmd_set_wall_msg rose ready",$host,"0","0"); 
   }
} # end rose_init

#### start rose ###############

sub rose_start
{
   my $host;

   print "\nstarting audiolan...\n";

   &manage_rose_audio("start") ;
   #rcmd("su - audiolan -c 'cd bin;./StartAudiolanSet $host_cfg'","sup1-s1","0","0");

   print "\n--->>> starting rose on masters ...<<<---\n\n";

   for $host (@MASTERS) { rcmd("$cmd_set_wall_msg rose starting",$host,"0","0"); }
   print("\nsleep $sleep{'set-wall-msg'}\n\n"); system("sleep $sleep{'set-wall-msg'}") if $EXEC;
   #--------------------------------------------------------------------------------------

   for $host (@MASTERS) { rcmd("$cmd_start_rose",$host,"0","0"); }
   print("\nsleep $sleep{'start-rose'}\n\n"); system("sleep $sleep{'start-rose'}") if $EXEC;
   #--------------------------------------------------------------------------------------

   for $host (@MASTERS) { rcmd("$cmd_set_wall_msg rose running",$host,"0","0"); }
   print("\nsleep $sleep{'set-wall-msg'}\n\n"); system("sleep $sleep{'set-wall-msg'}") if $EXEC;
   #--------------------------------------------------------------------------------------

   print "\n--->>> starting rose on slaves ...<<<---\n\n";

   for $host (@SLAVES) { rcmd("$cmd_set_wall_msg rose starting",$host,"0","0"); }
   print("\nsleep $sleep{'set-wall-msg'}\n\n"); system("sleep $sleep{'set-wall-msg'}") if $EXEC;
   #--------------------------------------------------------------------------------------

   for $host (@SLAVES) { rcmd("$cmd_start_rose",$host,"0","0"); }
   print("\nsleep $sleep{'start-rose'}\n\n"); system("sleep $sleep{'start-rose'}") if $EXEC;
   #--------------------------------------------------------------------------------------

   for $host (@SLAVES) { rcmd("$cmd_set_wall_msg rose running",$host,"0","0"); }

   #--------------------------------------------------------------------------------------
   # Start Info Display
   #--------------------------------------------------------------------------------------

   for $host (@MASTERS) { rcmd("$cmd_start_rose_info",$host,"0","0"); }
   for $host (@SLAVES)  { rcmd("$cmd_start_rose_info",$host,"0","0"); }
   #--------------------------------------------------------------------------------------
} # end start_rose

#### stop rose ###############

sub rose_stop
{
   my $host;

   print "\n>>> stopping rose..<<<\n\n";

   for $host (@SLAVES)
   {
     rcmd($cmd_stop_rose,$host,"0","0");
     rcmd("config_autologin.sh rose off",$host,"0","0");
     rcmd("$cmd_set_wall_msg rose hostname",$host,"0","0"); 
   }

   for $host (@MASTERS)
   {
     rcmd($cmd_stop_rose,$host,"0","0");
     rcmd("config_autologin.sh rose off",$host,"0","0");
     rcmd("$cmd_set_wall_msg rose hostname",$host,"0","0"); 
   }
   print "\n>>> stopping AudioLan...<<<\n\n";
   &manage_rose_audio("stop") ;
   #rcmd("su - audiolan -c 'cd bin;./StopAudiolanSet $host_cfg'","sup1-s1","0","0");

   #--------------------------------------------------------------------------------------
   # Stop Info Display
   #--------------------------------------------------------------------------------------

   for $host (@MASTERS) { rcmd("$cmd_stop_rose_info",$host,"0","0"); }
   for $host (@SLAVES)  { rcmd("$cmd_stop_rose_info",$host,"0","0"); }
   #--------------------------------------------------------------------------------------
}

sub rose_reboot
{
   my $host;

   print "reboot all master's and slaves !!\n";
   for $host (@SLAVES) { rcmd("reboot",$host,"out+err","0"); }
   for $host (@MASTERS) { rcmd("reboot",$host,"out+err","0"); }
}

sub rose_uptime
{
   my $host;

   print "get uptime of cwp's and psp's !!\n";
   for $host (@SLAVES) { print "$host: "; rcmd("uptime",$host,"out+err","0"); }
   for $host (@MASTERS) {print "$host: ";  rcmd("uptime",$host,"out+err","0"); }
}

sub rcmd
{
   my $cmd 	 = shift;
   my $host 	 = shift;
   my $exec_opt  = shift;
   my $print_cmd = shift;
   my $opt 	 = "";
   my $remsh     = "ssh"; 
   
   $remsh = "rsh" if ($client_type eq "sol");

   if     ($exec_opt eq "bg"       || $EXEC_OPT eq "bg"       ) {$opt = ' >/dev/null 2>&1 &';}
   elsif  ($exec_opt eq "quiet"    || $EXEC_OPT eq "quiet"    ) {$opt = ' >/dev/null 2>&1';}
   elsif  ($exec_opt eq "err_only" || $EXEC_OPT eq "err_only" ) {$opt = ' >/dev/null';}
   elsif  ($exec_opt eq "out+err"  || $EXEC_OPT eq "out+err"  ) {$opt = ' 2>&1';}
   else   { $opt = ' 2>/dev/null'; }

   #$cmd = "ssh $host \"" . $cmd. "\"" . $opt ;

   if ( $host ne "localhost" )
   { $cmd = "$remsh $host \"" . $cmd. "\"" . $opt ;}
   else
   { $cmd = $cmd.$opt ;}
   
   if ($PRINT_CMD == 1 || $print_cmd eq "print" ) { print "$cmd\n" ;};

   #if ( $EXEC ) { print("system(cmd)\n") ;} 
   if ( $EXEC ) { system($cmd);} 
 
}

sub rcopy
{
   my $source 	 = shift;
   my $target 	 = shift;
   my $exec_opt  = shift;
   my $print_cmd = shift;
   my $opt 	 = "";

   if     ($exec_opt eq "bg"       || $EXEC_OPT eq "bg"       ) {$opt = ' >/dev/null 2>&1 &';}
   elsif  ($exec_opt eq "quiet"    || $EXEC_OPT eq "quiet"    ) {$opt = ' >/dev/null 2>&1';}
   elsif  ($exec_opt eq "err_only" || $EXEC_OPT eq "err_only" ) {$opt = ' >/dev/null';}
   elsif  ($exec_opt eq "out+err"  || $EXEC_OPT eq "out+err"  ) {$opt = ' 2>&1';}
   else   { $opt = ""; }

   $cmd = "scp $source \'" . $target . "\' " .  $opt  ;

   if ($PRINT_CMD == 1 || $print_cmd eq "print" ) { print "$cmd\n" ;};

   #if ( $EXEC ) { print("system(cmd)\n") ;} 
   if ( $EXEC ) { system($cmd);} 
}

sub rsync
{
   my $source 	 = shift;
   my $target 	 = shift;
   my $exec_opt  = shift;
   my $print_cmd = shift;
   my $rsync_opt = shift;
   my $opt 	 = "";

   if     ($exec_opt eq "bg"       || $EXEC_OPT eq "bg"       ) {$opt = ' >/dev/null 2>&1 &';}
   elsif  ($exec_opt eq "quiet"    || $EXEC_OPT eq "quiet"    ) {$opt = ' >/dev/null 2>&1';}
   elsif  ($exec_opt eq "err_only" || $EXEC_OPT eq "err_only" ) {$opt = ' >/dev/null';}
   elsif  ($exec_opt eq "out+err"  || $EXEC_OPT eq "out+err"  ) {$opt = ' 2>&1';}
   else   { $opt = ""; }

   #$cmd = "scp $source \'" . $target . "\' " .  $opt  ;
   $cmd = "rsync -ahHv $rsync_opt \'$source\' \'$target\' $opt";

   if ($PRINT_CMD == 1 || $print_cmd eq "print" ) { print "$cmd\n" ;};

   #if ( $EXEC ) { print("system(cmd)\n") ;} 
   if ( $EXEC ) { system($cmd);} 
}

sub nsc_destroy
{
  my @FQDN_DIRS = ();
  my @PXE_FILES = ();
  my $host;
  my $fqdn_dir;
  my $pxe_file;
  my $file_path;
  my $my_cmd;
  my $yesno;

  print "pxe_client_dir= $pxe_client_dir\n";
  print "pxe_client_config_dir= $pxe_client_config_dir\n";

  print "\nDeleting config/FQDN directory(s)\nand PXE-FILES\n\n";

  opendir(PXE_CLIENT_CONFIG_DIR,$pxe_client_config_dir) or die $!;
  while ($fqdn_dir = readdir(PXE_CLIENT_CONFIG_DIR))
  {@FQDN_DIRS = (@FQDN_DIRS,$fqdn_dir) }
  opendir (PXE_CLIENT_DIR, $pxe_client_dir) or die $!;
  while ($pxe_file = readdir(PXE_CLIENT_DIR))
  {@PXE_FILES = (@PXE_FILES,$pxe_file) }

  for $host (@HOSTS_SELECTED)
  {
    print "\n----[[HOST $host ]]---------------\n";
    # delete hostlist entrys is not yet provided !!
    # $yesno = &promptUser("Really DELETE INSTALL INFOS and\nhostlist entrys from $host ?\n(no|yes) ","no");
    $yesno = &promptUser("Really REMOVE INSTALL INFOS for $host ? \n(no|yes) ","no");
    print "\nyou answered: $yesno\n";

    next if ($yesno ne "yes") ;

    for $fqdn_dir (@FQDN_DIRS)
    {
      my $dir_path = $pxe_client_config_dir . '/' . $fqdn_dir;
      $_ = $fqdn_dir;
      if (/^$host/)
      {
        if ($dir_path =~ /^\/srv\/inst\/xchg/) # to be save when something went wrong with the path. Who knows ...
        {
          $my_cmd = "mv $dir_path $pxe_client_config_dir" . '/_' . $fqdn_dir . "_" ;
          print $my_cmd."\n";
          system($my_cmd);
        } else { print "something went wrong: path to delete is \'$dir_path\' !! will NOT be deleted !!\n";}
      } 
    }

    for $pxe_file (@PXE_FILES)
    {
      my $file_path = $pxe_client_dir . '/' . $pxe_file;
      $_ = $pxe_file;
      if (/^pxe-hw.*$host/)
      {
        $my_cmd = "mv $file_path " . $pxe_client_dir . '/_' . $pxe_file . "_" ;
        print $my_cmd."\n";
        system($my_cmd);
      }
    }
  }
  print "\nWARNING: delete hostlist entrys is not yet provided !!\n";
  print "WARNING: please delete newsim+system.all.hosts and recreate with 'nsc_adm -q nsc' !!\n\n";
}

sub promptUser {

   local($promptString,$defaultValue) = @_;

   if ($defaultValue) {
     print $promptString, "[", $defaultValue, "]: ";
   } else {
     print $promptString, ": ";
   }
  $| = 1;               # force a flush after our print
  $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)
  chomp;

  if ("$defaultValue") {
    return $_ ? $_ : $defaultValue;    # return $_ if it has a value
  } else {
    return $_;
  }
}
