source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.txt
source /home/jenkins-slave/tools/keystonerc_admin
source /usr/local/src/hyperv-compute-ci-2016/jobs/library.sh

logs_project=compute-hyperv

set +e
set -f

[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned Stop-Service nova-compute'
[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned Stop-Service neutron-hyperv-agent'
run_wsmancmd_with_retry $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\OpenStack\hyperv-compute-ci\HyperV\scripts\export-eventlog.ps1'
run_wsmancmd_with_retry $hyperv01 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\OpenStack\hyperv-compute-ci\HyperV\scripts\collect_systemlogs.ps1'

[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned Stop-Service nova-compute'
[ "$IS_DEBUG_JOB" != "yes" ] && run_wsmancmd_with_retry $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned Stop-Service neutron-hyperv-agent'
run_wsmancmd_with_retry $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\OpenStack\hyperv-compute-ci\HyperV\scripts\export-eventlog.ps1'
run_wsmancmd_with_retry $hyperv02 $WIN_USER $WIN_PASS 'powershell -executionpolicy remotesigned C:\OpenStack\hyperv-compute-ci\HyperV\scripts\collect_systemlogs.ps1'

set +f
echo "Collecting logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$FLOATING_IP "/home/ubuntu/bin/collect_logs.sh $hyperv01 $hyperv02 $IS_DEBUG_JOB
"

echo "Downloading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$VMID.tar.gz"

gzip -9 /home/jenkins-slave/logs/console-$ZUUL_UUID.log
gzip -9 /home/jenkins-slave/logs/hyperv-build-log-$ZUUL_UUID-$hyperv01.log
gzip -9 /home/jenkins-slave/logs/hyperv-build-log-$ZUUL_UUID-$hyperv02.log
gzip -9 /home/jenkins-slave/logs/devstack-build-log-$ZUUL_UUID.log

if [ "$IS_DEBUG_JOB" != "yes" ]; then
    LOG_DST="/srv/logs/$logs_project/$ZUUL_CHANGE/$ZUUL_PATCHSET"
else
    TIMESTAMP=$(date +%d-%m-%Y_%H-%M)
    LOG_DST="/srv/logs/debug/$logs_project/$ZUUL_CHANGE/$ZUUL_PATCHSET/$TIMESTAMP"
fi

echo "LOG_DST=$LOG_DST"
echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ -z '$ZUUL_CHANGE' ] || [ -z '$ZUUL_PATCHSET' ]; then echo 'Missing parameters!'; exit 1; elif [ ! -d $LOG_DST ]; then mkdir -p $LOG_DST ; else rm -rf $LOG_DST/*; fi"

echo "Uploading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$VMID.tar.gz" logs@logs.openstack.tld:$LOG_DST/aggregate-logs.tar.gz

echo "Extracting logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "tar -xzf $LOG_DST/aggregate-logs.tar.gz -C LOG_DST/"
    
echo "Uploading temporary logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "/home/jenkins-slave/logs/console-$ZUUL_UUID.log.gz" logs@logs.openstack.tld:$LOG_DST/console.log.gz
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "/home/jenkins-slave/logs/hyperv-build-log-$ZUUL_UUID-$hyperv01.log.gz" logs@logs.openstack.tld:$LOG_DST/hyperv-build-log-$ZUUL_UUID-$hyperv01.log.gz
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "/home/jenkins-slave/logs/hyperv-build-log-$ZUUL_UUID-$hyperv02.log.gz" logs@logs.openstack.tld:$LOG_DST/hyperv-build-log-$ZUUL_UUID-$hyperv02.log.gz
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "/home/jenkins-slave/logs/devstack-build-log-$ZUUL_UUID.log.gz" logs@logs.openstack.tld:$LOG_DST/devstack-build-log-$ZUUL_UUID.log.gz

echo "Fixing permissions on all log files"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "chmod a+rx -R $LOG_DST"
	
echo "Removing local copy of aggregate logs"
rm -fv aggregate-$VMID.tar.gz

echo "Removing HyperV temporary console logs"
rm -fv /home/jenkins-slave/logs/hyperv-build-log-$ZUUL_UUID-$hyperv01.log.gz
rm -fv /home/jenkins-slave/logs/hyperv-build-log-$ZUUL_UUID-$hyperv02.log.gz

echo "Removing temporary devstack log.."
rm -fv /home/jenkins-slave/logs/devstack-build-log-$ZUUL_UUID.log.gz

echo "Removing temporary console log"
rm -fv /home/jenkins-slave/logs/devstack-build-log-$ZUUL_UUID.log.gz

echo `date -u +%H:%M:%S`
set -e
