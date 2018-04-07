#!/bin/bash
#
# EthosGeeK Script v1.5.0
#
# wget ?? -O /home/ethos/rigcheck.sh
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
LOG='/home/ethos/rig.log'
TLOG='/tmp/rig.log'
#
# Change number on the next line to what you set autoreboots to in your
# config file, the default is 5
CONFREB=5
#
# Pulling miner location
LOC=$(/opt/ethos/sbin/ethos-readconf loc)
#
# Ethos system file locations
autoreboot=$(/opt/ethos/sbin/ethos-readconf autoreboot)
rebcount=$(cat /opt/ethos/etc/autorebooted.file)
CRASHED=$(cat /var/run/ethos/crashed_gpus.file)
ERR=$(cat /var/run/ethos/status.file)
ALLOW=$(cat /opt/ethos/etc/allow.file)
#
# System Info
uptime=`sed 's/\..*//' /proc/uptime`
minersec=`grep miner_secs: /var/run/ethos/stats.file | cut -d \: -f 2`
updating=`cat /var/run/ethos/updating.file`
#
# Setting number variable
logsize="100"
NUMBR='[1-9]'
#
# To and From email addresses
EMI=email@mail.com
FEMI=miner_name@ethos.net
# To have mail working you will need to install sendmail
# sudo apt install sendmail

# Log checks and balances
if [[ -e /home/ethos/rig.log && -e /tmp/rig.log ]]; then
  echo "$(date) - Log file looks good! Cleaning up logs and moving on to rig checks..." | tee -a ${LOG}
  function f.truncatelog(){
	/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
	}

else
#if [[ -f /home/ethos/rig.log && -f /tmp/rig.log ]]; then
  echo "$(date) - Creating logs and setting the file permissions" | tee -a ${LOG}
 /usr/bin/sudo touch /home/ethos/rig.log
 /usr/bin/sudo /bin/cp /home/ethos/rig.log /tmp/rig.log
 /usr/bin/sudo /bin/chown ethos.ethos /home/ethos/rig.log /tmp/rig.log
 /usr/bin/sudo /bin/chmod 777 /home/ethos/rig.log /tmp/rig.log
   function f.truncatelog(){
	/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
   }
fi

# System and script checks
#if [ "$EUID" != 0 ]; then
#  echo "$(date) - Need to run script as root, if on Shell In A Box/SSH, use sudo $0" | tee -a ${TLOG}
#  exit 0
#fi

if [ ${TESTING} = true ]; then
  echo "$(date) - $0 TESTING mode set to ${TESTING}, set to false or auto-reboot/restart will not work!" | tee -a ${TLOG}
  exit 0
fi

#ALLOW=$(cat /opt/ethos/etc/allow.file)
#if [ ${ALLOW} != 1 ]; then
#  echo "$(date) - Miner process not enabled, bye $0..." | tee -a ${TLOG}
#  exit 0
#fi

# Now the good stuff, mine checks and balances

#if grep -q "too many autoreboots" /var/run/ethos/status.file
if [ ${rebcount} -ge ${CONFREB} ]; then
  #ACOUNT=$(cat /opt/ethos/etc/autorebooted.file)
  echo "$(date) Current autoreboot count is ${rebcount}, config limit is ${CONFREB}, clear thermals and check logs!!" | tee -a ${TLOG}
  echo "Subject: To Many Autoreboots!!" > mail.txt
  /usr/bin/tail -10 ${TLOG} >> mail.txt
  sendmail -f ${FEMI} -s ${EMI} >> /home/ethos/mail.txt
  # Disabling auto clear, ITS DANGEROUS!!
  #/opt/ethos/bin/clear-thermals
fi

if grep -q "gpu clock problem" /var/run/ethos/status.file; then
  #CRASHED=$(cat /var/run/ethos/crashed_gpus.file)
  echo "$(date) - GPU clock problem detected on GPU(s) ${CRASHED}, rebooting..." | tee -a ${TLOG}
  #rm -f /var/run/ethos/crashed_gpus.file
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot
fi

# Causing issues with dual reboots after daily reboot or update, disabling reboot code since there may be no issue
if   [[ $uptime -lt "100" ]] \
     || [[ $minersec -lt "100" ]] \
     || [[ $updating -eq "1" ]] \
     || [[ $ALLOW -eq "0" ]]; then
#if [[ `date +"%M"` == "00" ]] || [ -t 1 ] ; then
  #echo "$LOC $(date) - has mining disabled or its not mining long enough or no internet or upating $DT...check logs" | tee -a ${TLOG}
  echo "$(date) - Upime is: $uptime...check value is set to 100" | tee -a ${TLOG}
  echo "$(date) - Miner Mining Time: $minersec..check value is set to 100" | tee -a ${TLOG}
  echo "$(date) - Miner update status: $updating..check value is set to 1=updating" | tee -a ${TLOG}
  echo "$(date) - Miner enabled setting(should be 0, 1 is disabled): $ALLOW" | tee -a ${TLOG}
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/usr/bin/sudo /sbin/reboot
fi
#  fi

if [[ $error == "gpu crashed: reboot required" ]]; then
  echo "$(date) - CRAP! Looks to be a miner stall or GPU crash...check logs to confirm...rebooting!" | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot
fi

if [[ $error == "possible miner stall: check miner log" ]]; then
  echo "$(date) - CRAP! Looks to be a miner stall...check logs...rebooting!" | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

else
  echo "$(date) - Looking good, no work to be done, bye..." | tee -a ${TLOG}
fi
