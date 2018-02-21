#!/usr/bin/ksh
#
dbg=""

#
# set wallpaper message Version optional using xrandr 0.5 (Centos)
#
# (c) DFS, Peter Krauspe 2020-2017
#
#   
#
# set permission for creating temp files

#
# set wallpaper message Version 2.x (special Centos version for remote piloting)
#
# (c) DFS, Peter Krauspe 2020-2016
#
# Changes: 
#   12.11.2014: support display extendet mode for AFS and similiar applications
#   10.11.2015: display remote pilote status info
#   24.11.2015: update test
#   22.03.2016: added message indicating "makeThingsLocal" setting (via rpm installed check)
#   24.06.2017: black text colour for AFS mode
#   24.08.2016: added CSID for hostname option
#   
#   08.09.2016: added Centos Support ( not yet testet !!)
#   15.09.2016: changed basedir to /opt/local/wall_msg due to new sw architecture
#               (assumes tsctl2 still in old dir /opt/dfs !!)
#   01.11.2016: look for x11.vars in puppet-workdir
#   14.11.2016: set CS id string only when CSID is not "" 
#   27.01.2017: added config file wall_msg.cfg defining defaults: text colors and pic dir 
#   22.06.2017: - determines screen resolutions using xrandr instaedt of x11.vars
#               - added splash screen support (in development and commented out by default :-)
#               - calculate textSize[$res] from x-resolution if not found in x11.vars
#               - check existence if modefile before use
#               - check existence of bg file template, otherwise don't try to generate new image
#                
#   
#
# set permission for creating temp files
# TODO: check declaration of


log=/tmp/simcontrol.log

#d=$(date)
#echo "$d: BEGIN $(basename $0) $*" >> $log
#echo "$d: $(basename $0): checking /etc/resolv.conf" >> $log
#echo "------------------------------------------------" >> $log
#cat /etc/resolv.conf >> $log
#echo "------------------------------------------------" >> $log

umask 000
basedir=/opt/local/wall_msg
confdir=${basedir}/config
x11_confdir=/opt/puppet-workdir/x11_config
tmp_dir=/tmp/set_wall_msg
[[ -d $tmp_dir ]] || mkdir $tmp_dir
typeset pic_out=""

# set color and bg pics dir  defaults. may be overwritten from wall_msg.cfg !!
typeset -A COLOR1  # text color in the midle of the screen
typeset -A COLOR2  # text color at the bottom of the screen
typeset -A TextSize  # text sizes
typeset -A ScreenRes # screen reolutions <xres>x<yres>
typeset splashvideo
typeset -i splash=0

pics_set=cloud1_2

COLOR1[ready]=green
COLOR2[ready]=white

COLOR1[starting]=yellow
COLOR2[starting]=white

COLOR1[running]=red
COLOR2[running]=white

COLOR1[hostname]=white
COLOR1[hostname_remote]=green
COLOR2[hostname]=white

COLOR1[blank]=green
COLOR2[blank]=white

COLOR1[mode]=black
COLOR2[mode]=white

COLOR1[default]=white
COLOR2[default]=white

# read default settings and color settings of current pic set if any
source ${confdir}/wall_msg.cfg
picsdir=${basedir}/pics/$pics_set
[[ -f ${picsdir}/colors.cfg ]] && . ${picsdir}/colors.cfg 
videodir=${basedir}/videos

# get system vars
[[ -f /opt/puppet-workdir/hostparms/host.vars ]] && . /opt/puppet-workdir/hostparms/host.vars

# check host integrity
typeset conf_err=""
typeset remote_dn=""

fqdn_default=$(source /root/bootparms.txt ; echo $fqdn_default)

if [[ -n $fqdn_default ]] ; then

    dn_dhcp=$(grep ^search /etc/resolv.conf | awk '{print $2}')

    if [[ -z $dn_dhcp ]] ; then
      conf_err="No search domain !\n"
    else
        fqdn_current=$(cat /etc/hostname)
        dn_default=${fqdn_default#*.}
        dn_current=${fqdn_current#*.}
        if [[ -n $dn_dhcp && $dn_current != $dn_dhcp ]]; then
          conf_err="domain mismatch !\n"
        fi
    fi

    grep ^nameserver /etc/resolv.conf > /dev/null 2>&1

    if [[ $? -ne 0 ]]; then
      conf_err="${conf_err}No nameserver !"
    fi

    if [[ $dn_current != $dn_default ]]; then
      remote_dn=$dn_current
    fi
fi
# this may be useless, check
# get TSCTL vars (currently disabled: remote piloting has to be adapted for centos first)
#tsctl2_basedir=/opt/dfs/tsctl2
#tsctl2_confdir=${tsctl2_basedir}/config
#[[ -f ${tsctl2_confdir}/remote_nsc.cfg ]] && source ${tsctl2_confdir}/remote_nsc.cfg # providing:  subtype, ResourceDomainServers, RemoteDomainServers
#[[ -f ${tsctl2_confdir}/remote_nsc.${dn}.cfg ]] && source ${tsctl2_confdir}/remote_nsc.${dn}.cfg # read domain specific cfg
##

if [[ -f ${x11_confdir}/x11.vars ]] ; then
  . ${x11_confdir}/x11.vars
elif [[ -f ${confdir}/x11.vars ]] ; then
  . ${confdir}/x11.vars
elif [[ -f ${confdir}/x11.default.vars ]] ; then
  . ${confdir}/x11.default.vars
elif [[ -f /etc/2step/x11.vars ]] ; then
  . /etc/2step/x11.vars
else
  echo "no x11 config file found !! exiting.."
  exit 1
fi

# get parms or set defaults

mode=${1:-newsim}
status=${2:-hostname}

# set text colors

# midle text
color1=${COLOR1[default]}
color1_custom=${COLOR1[default]}
[[ -n "$3" ]] && color1_custom=$3

# bottom text
color2=${COLOR2[default]}

case $mode in
  spv|dap|pilot|trainee) mode=newsim
  ;;
esac

DISPLAY=""

host=$(hostname)
stype=${host:0:3}


# determine NEWSIM release (may change in the future !)
if [[ -f $PWD/active-release ]] ;then
  CSID=$(cat $PWD/active-release | sed -e 's/[a-zA-Z]*//g' -e 's/^-*//' -e 's/---/-/')
fi

# determine operation mode (AFS)
# TODO: adapt to new dir structure

if [[ -f /nss/home/config/mode/mode.txt ]]; then
  m=$(cat /nss/home/config/mode/mode.txt)
  extmode=$m'_CS'$CSID
  color1=${COLOR1[mode]}
else
  extmode="FAKE"
fi

echo "mode=$mode"

function CreateTextedImage
{
  #screen=$1
  res=$1
  pointsize=$2

  pic_out=${tmp_dir}/${mode}.${res}.jpg
  pic_tpl=$picsdir/${mode}.${res}.jpg

  if [[ -f $pic_tpl ]]; then
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
    echo $pic_out
  else
    echo ""
  fi
}

function SplashScreen
{
  screen=$1
  file=$2
  export DISPLAY=:0.$screen
  cvlc -f --play-and-exit $file
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
            color1=${COLOR1[ready]}
            text2=${host}${DISPLAY}
            color2=${COLOR2[ready]}
            ;;	
  
  starting*)
            text1="\n\ncoming up ...\non"
            color1=${COLOR1[starting]}
            text2=${host}${DISPLAY}
            color2=${COLOR2[starting]}
            ;;	
  
  running*)
            text1="\n\nrunning\non"
            color1=${COLOR1[running]}
            text2=${host}${DISPLAY}
            color2=${COLOR2[running]}
            ;;	
  hostname*)
            text2=${host}${DISPLAY}
            color2=${COLOR2[hostname]}
            if [[ -n $conf_err ]]; then
                text1=$conf_err
                color1=red
            elif [[ -n $remote_dn ]]; then
                text1="remote in $remote_dn"
                [[ -n $CSID ]] && text1="$text1 ($CSID)"
                color1=${COLOR1[hostname_remote]}
            fi

            # check if we are remote client
#            host -t txt $(hostname) | grep 'rnsc=1' > /dev/null 2>&1
#
#            if [ "$?" == "0" ]; then
#              text1="remote in\n $(dnsdomainname) ($CSID)"
#              color1=${COLOR1[hostname_remote]}
#            fi
       
            ;;	
  blank*)
            text1="" 
            color1=${COLOR1[blank]}
            text2=${host}${DISPLAY}
            color2=${COLOR2[blank]}
            ;;	
  mode*)
            text1="$extmode" 
            color1=$color1_custom
            text2=${host}${DISPLAY}
            color2=${COLOR2[mode]}
            ;;	
  *)
            text1="$status" 
            color1=$color1_custom
            text2=${host}${DISPLAY}
            color2=${COLOR2[default]}
            ;;	
  esac
}


function getTextSize 
{
  res=$1
  res_x=${res%x*}
  #res_y=${res#*x}

  if [[ -v ${TextSize[$res]} ]]; then
    echo ${TextSize[$res]} 
  else
    echo $((res_x/14)) 
  fi

}

echo "**********************************"

#for screen in ${!ScreenRes[*]}
#do
#     res=${ScreenRes[$screen]}
#     textsize=${TextSize[$res]}
#     echo "screen=$screen: $res $textsize"
#     SetVars $screen
#     pic_out=$(CreateTextedImage $res $textsize)
#     echo "Display  <$pic_out>"
#     #Display $screen $res $pic_out
#done
#debug exit



for screen in {0..5}
do
    SetVars $screen
    xrandr -display :0.$screen > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then 
      continue
    fi

    [[ -f ${tmp_dir}/xrandrbg.${screen}.conf ]] && rm ${tmp_dir}/xrandrbg.${screen}.conf

    xrandr -display :0.$screen | grep ' connected' | while read line
    do
      set -- $line
      echo $line
      id=$1
      if [[ $3 == *primary* ]]; then
        arg=$4
      else
        arg=$3
      fi

      res=$(echo $arg | sed 's/\([0-9]*\)x\([0-9]*\)\(.*\)/\1x\2/')

      # store it for later use
      ScreenRes[$screen]=$res

      #textsize=${TextSize[$res]}

      textsize=$(getTextSize $res)

      pic_out=$(CreateTextedImage $res $textsize)

      if [[ -n $pic_out ]]; then

        echo "screen=$screen id=$id  res=$res"

        cat <<-EOF >> ${tmp_dir}/xrandrbg.${screen}.conf
	output "$id" {
	file = "$pic_out"
	color = "#000000"
	mode = "centered"
	}
	EOF
      else
        echo "NO picture for resolution $res found. Skip creating background image for screen $sreen !!"
      fi
    done
    export DISPLAY=:0.$screen
    cat ${tmp_dir}/xrandrbg.${screen}.conf
    xrandrbg ${tmp_dir}/xrandrbg.${screen}.conf &
    #echo xrandrbg ${tmp_dir}/xrandrbg.${screen}.conf 
done

if (( $splash == 1 )) ; then
    if [[ -f ${videodir}/${splashvideo} ]] ; then
        video=$splashvideo
    elif [[ ${videodir}/rotating-newsim-bg.mp4 ]] ; then
        video=rotating-newsim-bg.mp4
        SplashScreen 0  ${videodir}/${video} &
    else
        echo "no splash video found !"
    fi
fi

#d=$(date)
#echo "$d: END $(basename $0) $*" >> $log
