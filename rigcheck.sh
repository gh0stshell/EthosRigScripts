#!/bin/bash
#
# EthosGeeK Script v1.5.5
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
# config file, add 1 to the number listed in your config
CONFREB=6
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
temps=$(grep ^temp: /var/run/ethos/stats.file | cut -d : -f 2 | sed 's/\...//g')
mems=$(grep ^memstates: /var/run/ethos/stats.file | cut -d : -f 2)"
hashes=$(tail -1 /var/run/ethos/miner_hashes.file)"
#
# Setting number variable
logsize="50"
NUMBR='[1-9]'
crashspeed="0"
#
# Logging function
function f.truncatelog(){
  /usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
}
#
# To(EMI) and From(FEMI) email addresses
EMI=email@domain.com
FEMI=miner_coin@ethos.net
#
# To have mail working you will need to install sendmail
# $ sudo apt install sendmail
#
# Log checks and balances
if [[ -e /home/ethos/rig.log && -e /tmp/rig.log ]]; then
  echo "$(date) - Log file looks good! Cleaning up logs and moving on to rig checks..." | tee -a ${TLOG}
  f.truncatelog
  #function f.truncatelog(){
	#/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
	#}
else
  echo "$(date) - Creating logs and setting log file permissions" | tee -a ${TLOG}
 /usr/bin/sudo touch /home/ethos/rig.log
 /usr/bin/sudo /bin/cp /home/ethos/rig.log /tmp/rig.log
 /usr/bin/sudo /bin/chown ethos.ethos /home/ethos/rig.log /tmp/rig.log
 /usr/bin/sudo /bin/chmod 777 /home/ethos/rig.log /tmp/rig.log
  f.truncatelog
  #function f.truncatelog(){
	#/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
   #}
fi

# Testing if script is in testing mode
if [ ${TESTING} = true ]; then
  echo "$(date) - $0 TESTING mode set to ${TESTING}, set to false or auto-reboot/restart will not work!" | tee -a ${TLOG}
  f.truncatelog
  exit 0
fi

# Miner health check with email option
#if grep -q "too many autoreboots" /var/run/ethos/status.file
if [ ${rebcount} -ge ${CONFREB} ]; then
  echo "$(date) Current autoreboot count is ${rebcount}, clear thermals and check logs!!" | tee -a ${TLOG}
  f.truncatelog
  #function f.truncatelog(){
    #/usr/bin/sudo tail -n $logsize /tmp/rig.log > /home/ethos/rig.log
   #}
  echo "Subject: To Many Autoreboots!!" > mail.txt
  /usr/bin/tail -10 ${TLOG} >> mail.txt
  sendmail -f ${FEMI} -s ${EMI} >> /home/ethos/mail.txt
  # Disabling auto clear, just sending emails for now
  #/opt/ethos/bin/clear-thermals
fi

if [[ $load == "5.0" && $load > "5.0" ]]; then
  echo "$(date) $LOC Load is high $load, login and check miner via top, could be bad wiring, bad riser, or OC settings" | tee -a ${TLOG}
  f.truncatelog
  echo "Subject: Miner Load Too High!" > loadmail.txt
  /usr/bin/tail -10 ${TLOG} >> loadmail.txt
  sendmail -f ${FEMI} -s ${EMI} >> /home/ethos/loadmail.txt
fi

# Settings GPU variable for hash check
for gpu in ${!hashrates[*]} ; do

# Miner checks with just logging
if   [[ $uptime -lt "120" ]] \
     || [[ $updating == "1" ]] \
     || [[ $ALLOW == "0" ]]; then
  echo "$(date) $LOC - Uptime is not long enough for check, current uptime is: $uptime" | tee -a ${TLOG}
  echo "$(date) $LOC - Miner is updating, update status is: $updating...1=updating" | tee -a ${TLOG}
  echo "$(date) $LOC - Miner enabled setting is $ALLOW (should be 1, 0 is disabled)" | tee -a ${TLOG}
  f.truncatelog
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/usr/bin/sudo /sbin/reboot

elif [[ $(bc <<< "${hashes[gpu]} <= $crashspeed") -eq "1" ]] ; then
  echo "$(date) $LOC - Hashrate check shows GPU(s) have crashed Status: "${hashes[*]}" "${mems[*]}"" | tee -a ${TLOG}
  f.truncatelog
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif grep -q "miner started: miner commanded to start" /var/run/ethos/status.file; then
  sleep 300

elif grep -q "miner active" /var/run/ethos/status.file && [ $minersec -lt "60" ]; then
  echo "$(date) - Miner mining time is too low, current mining time is: $minersec" | tee -a ${TLOG}
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  #/opt/ethos/bin/minestart
  #/opt/ethos/bin/minestop
  f.truncatelog

elif [ $mems == "0" ]; then
  echo "Memstates show GPU(s) have crashed and/or not mining for a while Status: $mems" | tee -a ${TLOG}
  f.truncatelog
  #((rebcount++))
  #echo $rebcount > /opt/ethos/etc/autorebooted.file
  /opt/ethos/bin/minestop

elif grep -q "gpu clock problem" /var/run/ethos/status.file; then
  echo "$(date) - $LOC has a GPU clock problem detected on GPU(s) ${CRASHED} $mems $hashes" | tee -a ${TLOG}
  f.truncatelog
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error == "gpu crashed: reboot required" ]]; then
  echo "$(date) - CRAP! Looks to be a miner stall or GPU crash Status: $mems $hashes $error" | tee -a ${TLOG}
  f.truncatelog
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error == "possible miner stall: check miner log" ]]; then
  echo "$(date) - CRAP! Looks to be a miner stall Status: $mems $hashes $error" | tee -a ${TLOG}
  f.truncatelog
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $error = "hardware error: possible gpu/riser/power failure" ]]; then
  echo "$(date) $error - http://ethosdistro.com/kb/#adl" | tee -a ${TLOG}
  f.truncatelog
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

elif [[ $throttled -eq "1" ]]; then
  echo "$(date) $LOC has a GPU that overheated $mems $temps - http://ethosdistro.com/kb/#managing-temperature" | tee -a ${TLOG}
  f.truncatelog
  ((rebcount++))
  echo $rebcount > /opt/ethos/etc/autorebooted.file
  /usr/bin/sudo /sbin/reboot

else
  echo "$(date) - Looking good, no work to be done, miner doing its thing..." | tee -a ${TLOG}
  echo "$(date) - $mems $hashes $temps" | tee -a ${TLOG}
  f.truncatelog
fi
