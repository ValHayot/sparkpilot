#!/bin/bash

echo start $(date +%s.%N) > $mstr_bench
echo 'NODE: ' $(hostname) $(hostname -i)

module load spark/2.3.0
#module load python

export SPARK_IDENT_STRING=$SLURM_JOBID
export SPARK_WORKER_DIR=$SLURM_TMPDIR

$SPARK_HOME/sbin/start-master.sh
if [ ! -f $mstr_log ]; then
    lockfile -r 0 $mstr_lock
    if [ $? -eq 0 ]; then
	while [ -z "$MASTER_URI" ]
	do
		MASTER_URI=$(curl -s http://localhost:8080/json/ | jq -r ".url")
		sleep 5
	done
        echo $MASTER_URI > $mstr_log
    else
        while [ ! -f $mstr_log ]; do sleep 5; done
        MASTER_URI=$(head -n 1 $mstr_log)
    fi
else
    MASTER_URI=$(head -n 1 $mstr_log)
fi

echo 'RUNNING MASTER: ' $MASTER_URI

$SPARK_HOME/sbin/start-slave.sh -m ${SLURM_MEM_PER_NODE}M -c ${SLURM_CPUS_PER_TASK} $MASTER_URI 

while [[ $(tail -n 1 $mstr_log) != "SUCCEEDED" ]]; do
	sleep 5
done
$SPARK_HOME/sbin/stop-slave.sh
$SPARK_HOME/sbin/stop-master.sh
rm -f $mstr_lock
echo end $(date +%s.%N) >> $mstr_bench
