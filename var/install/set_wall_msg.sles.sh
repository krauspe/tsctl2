#!/usr/bin/ksh
#
dbg=""
#dbg=echo
#
# set wallpaper message Version 1.2
#
# (c) DFS, Peter Krauspe 2015
#
# Changes: 
#   12.11.2014: support display extendet mode for AFS and similiar applications
#   10.11.2015: display remote pilote status info
#   24.11.2015: update test
#   22.03.2016: added message indicating "makeThingsLocal" setting (via rpm installed check)
#
# set permission for creating temp files
umask 000

if [[ -f /etc/2step/x11.vars ]] ; then 
  . /etc/2step/x11.vars
else
  echo "/etc/2step/x11.vars not found !! exiting.."
  exit 1
fi

# getting TSCTL vars
tsctl2_basedir=/opt/dfs/tsctl2
tsctl2_confdir=${tsctl2_basedir}/config
source ${tsctl2_confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
[[ -f ${tsctl2_confdir}/remote_nsc.${dn}.cfg ]] && source ${tsctl2_confdir}/remote_nsc.${dn}.cfg # read domain specific cfg
##


#debug
#. ./x11.ak3.lgn.dfs.de.vars

mode=$1
status=$2
color1=white
color2=white
color1_custom=black
[[ -n "$3" ]] && color1_custom=$3

case $mode in
  spv|dap|pilot|trainee) mode=newsim
  ;;
esac

basedir=/usr/local/share/wall_msg
pic_out=/tmp/tmp.jpg
picpath=$basedir/pics
DISPLAY=""

host=$(hostname)
stype=${host:0:3}

# determine operation mode (AFS)

if [[ -f /nss/home/config/mode/mode.txt ]]; then
  m=$(cat /nss/home/config/mode/mode.txt)
  x=$(ls -lcd /nss/home/spv/newsim_rel1/active_release)
  extmode=$m'_CS'${x: -3}
else
  extmode=""
fi


function SetText
{
  screen=$1
  size=$2
  pointsize=$3

  echo "text1=$text1 text2=$text2"
  pic_tpl=$picpath/${mode}.${size}.jpg

  if [[ $text1 != "" ]]
  then
    convert $pic_tpl  -pointsize $pointsize \
                 -gravity center -fill $color1  -annotate 0 "$text1" \
                 -gravity south -fill $color2  -annotate 0 "$text2" \
            $pic_out
  else
    convert $pic_tpl  -pointsize $pointsize \
                 -gravity south -fill $color2  -annotate 0 "$text2" \
            $pic_out
  fi
}

function Display
{
  screen=$1
  size=$2
  file=$3
  export DISPLAY=:0.$screen
  echo display -window root -sample $size $file
  display -window root -sample $size $file
}

function SetVars
{
  screen=$1
  [[ -f $basedir/show_screens ]] && DISPLAY=:0.$screen

  case "$status" in 
  
  ready*)
            text1='\n\nready for launch\non' 
            color1=green
            text2=${host}${DISPLAY}
            color2=white
            ;;	
  
  starting*)
            text1="\n\ncoming up ...\non"
            color1=yellow
            text2=${host}${DISPLAY}
            color2=white
            ;;	
  
  running*)
            text1="\n\nrunning\non"
            color1=red
            text2=${host}${DISPLAY}
            color2=white
            ;;	
  hostname*)
            text1="" 
            text2=${host}${DISPLAY}
            color2=white
            # check if we are remote client
            host -t txt $(hostname) | grep 'rnsc=1' > /dev/null 2>&1

            if [ "$?" == "0" ]; then
              text1="remote psp in\n $(dnsdomainname) (CS$CSID)"
              /sbin/chkconfig | egrep 'makeThingsLocal.*on' > /dev/null 2>&1
              if [[ $? -eq 0 ]]; then
                text1="${text1}\nmadeThingsLocal"
              fi

              color1=green
            fi

            #OLD version
            #if [[ -f /etc/2step/2step.vars ]];then
            #  default_dn=$(grep ^dn /etc/2step/2step.vars); default_dn=${default_dn#*\"}; default_dn=${default_dn%\"}
            #  if [[ $default_dn != $(dnsdomainname) ]] ; then
            #     text1="remote psp in\n $(dnsdomainname)"
            #     color1=green
            #     rpm -qa | grep $client_rpm_name >/dev/null 2>&1
            #     if [[ $? -eq 0 ]]; then
            #       text1="${text1}\nmadeThingsLocal"
            #     fi
            #  fi
            #fi
            ;;	
  blank*)
            text1="" 
            color1=green
            text2=${host}${DISPLAY}
            color2=white
            ;;	
  mode*)
            text1="$extmode" 
            color1=$color1_custom
            text2=${host}${DISPLAY}
            color2=white
            ;;	
  *)
            text1="$status" 
            color1=$color1_custom
            text2=${host}${DISPLAY}
            color2=white
            ;;	
  esac
}


for screen in ${!ScreenRes[*]}
do
     res=${ScreenRes[$screen]}
     textsize=${TextSize[$res]}
     echo "screen=$screen: $res $textsize"
     $dbg SetVars $screen
     $dbg SetText $screen $res $textsize
     $dbg Display $screen $res $pic_out
	
done


