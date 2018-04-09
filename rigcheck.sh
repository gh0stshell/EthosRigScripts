#!/bin/bash
#
# EthosGeeK Script v1.5.3
#
# wget -4 https://github.com/gh0stshell/EthosRigScripts/raw/master/rigcheck.sh -O /home/ethos/rigcheck.sh
# chmod u+x rigcheck.sh
# Crontab -e
# */10 * * * * sudo /home/ethos/rigcheck.sh
#
# Set TESTING to false to enable autoreboot, set as true to test the script
TESTING=false
#
# Add the following line to your remote config or local.conf in order for autoreboot
# or reboot to actually work, add without the # at the beginning of the line
# autoreboot=5
#
# Establishing log files
LOG='/home/ethos/rig.log'
TLOG='/tmp/rig.log'
#
# Change number on the next line to what you set autoreboots to in your
# config file, the default is 5
CONFREB=5
#
# Pulling ethos system info
LOC=$(/opt/ethos/sbin/ethos-readconf loc)
autoreboot=$(/opt/ethos/sbin/ethos-readconf autoreboot)
rebcount=$(cat /opt/ethos/etc/autorebooted.file)
CRASHED=$(cat /var/run/ethos/crashed_gpus.file)
ERR=$(cat /var/run/ethos/status.file)
ALLOW=$(cat /opt/ethos/etc/allow.file)
throttled=$(cat /var/run/ethos/throttled.file)
minersec=`grep miner_secs: /var/run/ethos/stats.file | cut -d \: -f 2`
updating=`cat /var/run/ethos/updating.file`
load=$(cat /proc/loadavg | awk '{ print $1 }')
uptime=`sed 's/\..*//' /proc/uptime`
read -r -a temps <<< "$(grep ^temp: /var/run/ethos/stats.file | cut -d : -f 2 | sed 's/\...//g')"
read -r -a memstates <<< "$(grep ^memstates: /var/run/ethos/stats.file | cut -d : -f 2)"
read -r -a hashrates <<< "$(tail -1 /var/run/ethos/miner_hashes.file)"
#
# Setting number variable
logsize="50"
NUMBR='[1-9]'
#
# To and From email addresses
EMI=name@domain.com
FEMI=miner_name@ethos.net
# To have mail working you will need to install sendmail
# $ sudo apt install sendmail
#
# Log checks and balances
if [[ -e /home/ethos/rig.log && -e /tmp/rig.log ]]; then
  echo "$(date) - Log file looks good! Cleaning up logs and moving on to rig checks..." | tee -a ${LOG}
  function f.truncatelog(){
	/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
	}
else
  echo "$(date) - Creating logs and setting the file permissions" | tee -a ${LOG}
 /usr/bin/sudo touch /home/ethos/rig.log
 /usr/bin/sudo /bin/cp /home/ethos/rig.log /tmp/rig.log
 /usr/bin/sudo /bin/chown ethos.ethos /home/ethos/rig.log /tmp/rig.log
 /usr/bin/sudo /bin/chmod 777 /home/ethos/rig.log /tmp/rig.log
   function f.truncatelog(){
	/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
   }
fi

# Testing if script is in testing mode
if [ ${TESTING} = true ]; then
  echo "$(date) - $0 TESTING mode set to ${TESTING}, set to false or auto-reboot/restart will not work!" | tee -a ${TLOG}
  exit 0
fi

# Miner health check with email option
#if grep -q "too many autoreboots" /var/run/ethos/status.file
if [ ${rebcount} -ge ${CONFREB} ]; then
  #ACOUNT=$(cat /opt/ethos/etc/autorebooted.file)
  echo "$(date) Current autoreboot count is ${rebcount}, config limit is ${CONFREB}, clear thermals and check logs!!" | tee -a ${TLOG}
  echo "Subject: To Many Autoreboots!!" > mail.txt
  /usr/bin/tail -10 ${TLOG} >> mail.txt
  sendmail -f ${FEMI} -s ${EMI} >> /home/ethos/mail.txt
  # Disabling auto clear, just sending emails for now
  #/opt/ethos/bin/clear-thermals
fi

if [[ $load == "1.6" && $load > "1.6" ]]; then
  echo "$(date) $LOC Load is high, login and check miner via top, could be bad wiring or riser" | tee -a ${TLOG}
  echo "Subject: Miner Load High!" > loadmail.txt
  /usr/bin/tail -10 ${TLOG} >> loadmail.txt
  sendmail -f ${FEMI} -s ${EMI} >> /home/ethos/loadmail.txt
fi

# Miner checks with just logging
if   [[ $uptime -lt "100" ]] \
     || [[ $updating -eq "1" ]] \
     || [[ $ALLOW -eq "0" ]]; then
  echo "$LOC $(date) - mining disabled or upating $DT...check logs" | tee -a ${TLOG}
  echo "$(date) - Upime is: $uptime...check value is set to 100" | tee -a ${TLOG}
  #echo "$(date) - Miner Mining Time: $minersec..check value is set to 100" | tee -a ${TLOG}
  echo "$(date) - Miner update status: $updating..checking value it is set to 1=updating" | tee -a ${TLOG}
  echo "$(date) - Miner enabled setting(should be 1, 0 is disabled): $ALLOW" | tee -a ${TLOG}
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/usr/bin/sudo /sbin/reboot
#fi

elif grep -q "miner started" /var/run/ethos/status.file; then
  sleep 300

#elif [ $minersec -lt "120" ]; then
elif [[ $error == "miner active" && $minersec -lt "120" ]]; then
#elif grep -q "miner active" /var/run/ethos/status.file && $minersec -lt "120"; then
  echo "$(date) - Miner Mining Time: $minersec..check value is set to 120" | tee -a ${TLOG}
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/opt/ethos/bin/minestart
  #/opt/ethos/bin/minestop

elif grep -q "gpu clock problem" /var/run/ethos/status.file; then
  echo "$(date) - GPU clock problem detected on GPU(s) ${CRASHED}, rebooting..." | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error == "gpu crashed: reboot required" ]]; then
  echo "$(date) - CRAP! Looks to be a miner stall or GPU crash...check logs to confirm...rebooting!" | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error == "possible miner stall: check miner log" ]]; then
  echo "$(date) - CRAP! Looks to be a miner stall...check logs...rebooting!" | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error = "hardware error: possible gpu/riser/power failure" ]]; then
  echo "$error - http://ethosdistro.com/kb/#adl $DT" | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $throttled -eq "1" ]]; then
  echo "$loc has a GPU that overheated - http://ethosdistro.com/kb/#managing-temperature $DT" | tee -a ${TLOG}
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

else
  echo "$(date) - Looking good, no work to be done, bye..." | tee -a ${TLOG}
fi
