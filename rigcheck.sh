#!/bin/bash
#
# EthosGeeK Script v1.4.6
# More to come!!
#
# chmod u+x rigcheck.sh
# Crontab -e
# */10 * * * * sudo /home/ethos/rigcheck.sh
#
# Set TESTING to false to enable auto-restart/reboot, set as true to test the script
TESTING=false
# Add the following line to your remote config or local.conf in order for autoreboot
# or reboot to actually work, add without the # at the beginning of the line
# autoreboot=5
#
# Establishing log file
LOG=/home/ethos/rig.log
#
# Change number on the next line to what you set autoreboots to in your
# config file, the default is 5
CONFREB=5
#
# Setting file location for error detection
ERR=$(cat /var/run/ethos/status.file)
#
# Pulling miner location
LOC=$(/opt/ethos/sbin/ethos-readconf loc)
#
# Setting AutoReboot file location
autoreboot=$(/opt/ethos/sbin/ethos-readconf autoreboot)
rebcount=$(cat /opt/ethos/etc/autorebooted.file)
#
# Setting number variable
NUMBR='[1-9]'
#
# Setting To and From email addresses
EMI=jpgottech@gmail.com
FEMI=tatiana@ethos.net
# To have mail working you will need to install sendmail
# sudo apt install sendmail

if [ "$EUID" != 0 ]; then
  echo "Need to run script as root, if on Shell In A Box/SSH, use sudo $0" | tee -a $"LOG"
  exit 0
fi

if [ ${TESTING} = true ]; then
  echo "$(date) $0 TESTING mode set to ${TESTING}, set to false or auto-reboot/restart will not work!" | tee -a $"LOG"
  exit 0
fi

ALLOW=$(cat /opt/ethos/etc/allow.file)
if [ ${ALLOW} != 1 ]; then
  echo "$(date) Miner process not enabled, bye $0..." | tee -a $"LOG"
  exit 0
fi

REBC=$(cat /opt/ethos/etc/autorebooted.file)
ACOUNT=$(cat /opt/ethos/etc/autorebooted.file)
##if grep -q "too many autoreboots" /var/run/ethos/status.file
if [ ${REBC} -ge "$CONFREB" ]; then
  #ACOUNT=$(cat /opt/ethos/etc/autorebooted.file)
  echo "$(date) Current autoreboot count is ${ACOUNT}, config limit is ${CONFREB}, clear thermals and check logs!!" | tee -a $"LOG"
  echo "Subject: To Many Autoreboots!!" > mail.txt
  /usr/bin/tail -10 $"LOG" >> mail.txt
  sendmail -f ${FEMI} -s ${EMI} >> /home/ethos/mail.txt
  # Disabling auto clear, ITS DANGEROUS!!
  #/opt/ethos/bin/clear-thermals

# change if to elif after uncommenting statement above
CRASHED=$(cat /var/run/ethos/crashed_gpus.file)
elif grep -q "gpu clock problem" /var/run/ethos/status.file; then
  #CRASHED=$(cat /var/run/ethos/crashed_gpus.file)
  echo "$(date) GPU clock problem detected on GPU(s) ${CRASHED}, rebooting..." | tee -a $"LOG"
  #rm -f /var/run/ethos/crashed_gpus.file
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

# Reboots when there is no issue, disabling for testing
#elif [[ $(date +"%M") == "00" ]] || [ -t 1 ] ; then
  #echo "$LOC Disallowed, Not mining long enough or No internet or Upating $DT" | tee -a $"LOG"
  #/usr/bin/sudo /sbin/reboot
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/usr/bin/sudo /sbin/reboot

elif [[ $error == "gpu crashed: reboot required" ]]; then
#|| [[ $error == "possible miner stall: check miner log" ]] ; then
  echo "CRAP! Looks to be a miner stall or GPU crash...check logs to confirm...rebooting!" | tee -a $"LOG"
  #/usr/bin/sudo /sbin/reboot
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error == "possible miner stall: check miner log" ]]; then
  echo "CRAP! Looks to be a miner stall...check logs...rebooting!" | tee -a $"LOG"
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

# Possibly accounting for daily reboots instead of just autoreboots by script, disabling
#elif [[ $autoreboot =~ $NUMBR ]] && [[ $autoreboot -gt $rebcount ]] ; then
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/usr/bin/sudo /opt/ethos/bin/clear-thermals

else
  echo "Looking good, no work to be done, bye..."
fi
