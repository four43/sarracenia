#!/bin/bash

# make sure libsrshim is off

# if running local sarra/sarrac versions, specify path to them with 
# $SARRA_LIB and $SARRAC_LIB, and $SR_POST_CONFIG 
# contains the path to shim_f63.conf (usually in $CONFDIR/cpost/
# shimpost.conf, but specify if otherwise)
# defaults:
#export SR_POST_CONFIG="$CONFDIR/post/shim_f63.conf"
#export SARRA_LIB=""
#export SARRAC_LIB=""


. ./flow_utils.sh
export TESTDIR="`pwd`"
#export PYTHONPATH="`pwd`/../"
testdocroot="$HOME/sarra_devdocroot"
testhost=localhost
sftpuser=`whoami`

eval `application_dirs`

if [ -d $CACHEDIR/log ]; then
    logs2remove=$(find "$CACHEDIR"/log/ -iname "*.txt" -o -iname "*.log")
    if [ ! -z "$logs2remove" ]; then
       echo "Cleaning logs, just in case"
       rm $(find "$CACHEDIR"/log/ -iname "*.txt" -o -iname "*.log")
    fi
fi

if [ ! -f "$CONFDIR"/admin.conf -o ! -f "$CONFDIR"/credentials.conf ]; then
 cat <<EOT
 ERROR:
 test users for each role: tsource, tsub, tfeed, bunnymaster (admin)
 need to be created before this script can be run.
 rabbitmq-server needs to be installed on a machine (FLOWBROKER) with admin account set and
 manually setup in "$CONFDIR"/admin.conf, something like this:

declare env FLOWBROKER=localhost
declare env SFTPUSER="`whoami`"
declare env TESTDOCROOT=${HOME}/sarra_devdocroot

broker amqp://tsource@localhost/
admin amqp://bunnymaster@localhost
feeder  amqp://tfeed@localhost
declare source tsource
declare subscriber tsub
declare subscriber anonymous

and "$CONFDIR"/credentials.conf will need to contain something like:

amqp://bunnymaster:PickAPassword@localhost
ftp://anonymous:anonymous@localhost:2121/
amqp://tsource:PickAPassword2@localhost
amqp://tfeed:PickAPassword3@localhost
amqp://tsub:PickAPassword4@localhost
amqp://anonymous:PickAPassword5@localhost
amqps://anonymous:anonymous@dd.weather.gc.ca
amqps://anonymous:anonymous@dd1.weather.gc.ca
amqps://anonymous:anonymous@dd2.weather.gc.ca

EOT
 exit 1
fi
 
if [ ! -d "$testdocroot" ]; then
  mkdir $testdocroot
  cp -r testree/* $testdocroot
  mkdir $testdocroot/downloaded_by_sub_t
  mkdir $testdocroot/downloaded_by_sub_u
  mkdir $testdocroot/sent_by_tsource2send
  mkdir $testdocroot/recd_by_srpoll_test1
  mkdir $testdocroot/posted_by_srpost_test2
  mkdir $testdocroot/posted_by_shim
  mkdir $testdocroot/cfr
  mkdir $testdocroot/cfile
fi

lo="`netstat -an | grep '127.0.0.1:8001'|wc -l`"
while [ ${lo} -gt 0 ]; do
   echo "Waiting for $lo leftover sockets to clean themselves up from last run."
   sleep 10 
   lo="`netstat -an | grep '127.0.0.1:8001'|wc -l`"
   sleep 5 
done

mkdir -p "$CONFDIR" 2> /dev/null


export SR_CONFIG_EXAMPLES=`pwd`/../sarra/examples


flow_configs="`cd ../sarra/examples; ls */*f[0-9][0-9].conf; ls */*f[0-9][0-9].inc`"
sr_action "Adding flow test configurations..." add "$flow_configs"

# sr_post "add" doesn't. so a little help:
mkdir ${CONFDIR}/post 2> /dev/null
cp ../sarra/examples/post/*f[0-9][0-9].conf ${CONFDIR}/post


passed_checks=0
count_of_checks=0

#xchk 8 "only rabbitmq default systems exchanges should be present."

# ensure users have exchanges:

echo "Initializing with sr_audit... takes a minute or two"
if [ ! "$SARRA_LIB" ]; then
    sr_audit --users foreground >$LOGDIR/sr_audit_f00.log 2>&1
else
    "$SARRA_LIB"/sr_audit.py --users foreground >$LOGDIR/sr_audit_f00.log 2>&1
fi

qchk 20 "queues existing after 1st audit" 

xchk "exchanges for flow test created"

if [ "$1" = "declare" ]; then
   exit 0
fi

testrundir="`pwd`"

echo "Starting trivial http server on: $testdocroot, saving pid in .httpserverpid"
cd $testdocroot
$testrundir/trivialserver.py >trivialhttpserver.log 2>&1 &
httpserverpid=$!


echo "Starting trivial ftp server on: $testdocroot, saving pid in .ftpserverpid"

# note, on older OS, pyftpdlib might need to be installed as a python2 extension.
# 
# note, defaults to port 2121 so devs can start it.

if [ "`lsb_release -rs`" = "14.04"  ]; then
   python -m pyftpdlib >trivialftpserver.log 2>&1 &
else
   python3 -m pyftpdlib >trivialftpserver.log 2>&1 &
fi
ftpserverpid=$!

sleep 3

if [ ! "`head trivialftpserver.log | grep 'starting'`" ]; then
   echo "FAILED to start FTP server, is pyftpdlib installed?"
else
   echo "FTP server started." 
   passed_checks=$((${passed_checks}+1))
fi
count_of_checks=$((${count_of_checks}+1))


echo "running self test ... takes a minute or two"

cd ${TESTDIR}
echo "Unit tests ("`date`")" > ${testdocroot}/unit_tests.log

nbr_test=0
nbr_fail=0

count_of_checks=$((${count_of_checks}+1))

for t in sr_util sr_credentials sr_config sr_cache sr_retry sr_consumer sr_http sr_sftp sr_instances sr_pattern_match; do
    echo "======= Testing :"${t}  >>  ${testdocroot}/unit_tests.log
    nbr_test=$(( ${nbr_test}+1 ))
      ${TESTDIR}/unit_tests/${t}_unit_test.py >> ${testdocroot}/unit_tests.log 2>&1
      status=${?}
            if [ $status -ne 0 ]; then
               echo "======= Testing "${t}": Failed"
            else
               echo "======= Testing "${t}": Succeeded"
            fi

    nbr_fail=$(( ${nbr_fail}+${status} ))
done

if [ $nbr_fail -ne 0 ]; then
   echo "FAILED: "${nbr_fail}" self test did not work"
   echo "        Have a look in file "${testdocroot}/unit_tests.log
else
   echo "OK, as expected "${nbr_test}" tests passed"
   passed_checks=$((${passed_checks}+1))
fi


cd $testrundir

echo "Starting flow_post on: $testdocroot, saving pid in .flowpostpid"
./flow_post.sh >${LOGDIR}/srposter.log 2>&1 &
flowpostpid=$!


echo $ftpserverpid >.ftpserverpid
echo $httpserverpid >.httpserverpid
echo $testdocroot >.httpdocroot
echo $flowpostpid >.flowpostpid

if [ ${#} -ge 1 ]; then
export MAX_MESSAGES=${1}
echo $MAX_MESSAGES
fi

flow_configs="audit/ poll/pulse.conf `cd ../sarra/examples; ls */*f[0-9][0-9].conf`"
sr_action "Starting up all components (sr start)..." start "$flow_configs"
echo "Done."

#sr_subscribe stop fclean
#sr_subscribe cleanup fclean
#sr_subscribe remove fclean

ret=$?

count_of_checks=$((${count_of_checks}+1))
if [ $ret -ne 0 ]; then
   echo "FAILED: sr start returned error status"
else
   echo "OK: sr start was successful"
   passed_checks=$((${passed_checks}+1))
fi

if [ $passed_checks = $count_of_checks ]; then
   echo "Overall: PASSED $passed_checks/$count_of_checks checks passed!"
else
   echo "Overall: FAILED $passed_checks/$count_of_checks passed."
fi
