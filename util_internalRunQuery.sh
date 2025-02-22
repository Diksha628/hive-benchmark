#!/bin/bash

INTERNAL_DATABASE=$1
INTERNAL_SETTINGSPATH=$2
INTERNAL_QUERYPATH=$3
INTERNAL_LOG_PATH=$4
INTERNAL_QID=$5
INTERNAL_CSV=$6
TYPE=$7

TIME_TO_TIMEOUT=120m
MODE='default'
HOSTNAME=$(hostname -f)

if [[ "$TYPE" == "hilo" ]]; then
    HOSTNAME="hive-interactive"
fi

# Beeline command to execute
START_TIME="$(date +%s.%N)"

if [[ "${MODE}" == 'default' ]]; then
    timeout "${TIME_TO_TIMEOUT}" beeline -u "jdbc:hive2://${HOSTNAME}:10001/${INTERNAL_DATABASE};transportMode=http" -i "${INTERNAL_SETTINGSPATH}" -f "${INTERNAL_QUERYPATH}" &>> "${INTERNAL_LOG_PATH}"
    RETURN_VAL=$?
elif [[ "${MODE}" == 'esp' ]]; then
    AAD_DOMAIN='MY_DOMAIN.COM'
    USERNAME='hive'
    PASSWORD='YOURPASSWORD'
    kdestroy
    echo "${PASSWORD}" | kinit "${USERNAME}"
    timeout "${TIME_TO_TIMEOUT}" beeline -u "jdbc:hive2://${HOSTNAME}:10001/${INTERNAL_DATABASE};transportMode=http;httpPath=cliservice;principal=hive/_HOST@${AAD_DOMAIN}" -n "${USERNAME}" -i "${INTERNAL_SETTINGSPATH}" -f "${INTERNAL_QUERYPATH}" &>> "${INTERNAL_LOG_PATH}"
    RETURN_VAL=$?
elif [[ "${MODE}" == 'gateway' ]]; then
    CLUSTERNAME='MYCLUSTER'
    USERNAME='admin'
    PASSWORD='YOURPASSWORD'
    timeout "${TIME_TO_TIMEOUT}" beeline -u "jdbc:hive2://${CLUSTERNAME}.azurehdinsight.net:443/${INTERNAL_DATABASE};ssl=true;transportMode=http;httpPath=/hive2" -n "${USERNAME}" -p "${PASSWORD}" -i "${INTERNAL_SETTINGSPATH}" -f "${INTERNAL_QUERYPATH}" &>> "${INTERNAL_LOG_PATH}"
    RETURN_VAL=$?
else
    echo "MODE must be 'default' | 'esp' | 'gateway'"
    exit 1
fi

END_TIME="$(date +%s.%N)"

if [[ "${RETURN_VAL}" == 0 ]]; then
    secs_elapsed="$(echo "$END_TIME - $START_TIME" | bc -l)"
    echo "${INTERNAL_QID}, ${secs_elapsed}, SUCCESS" >> "${INTERNAL_CSV}"
    echo "query${INTERNAL_QID}: SUCCESS"
else
    echo "${INTERNAL_QID}, , FAILURE" >> "${INTERNAL_CSV}"
    echo "query${INTERNAL_QID}: FAILURE"
    echo "Status code was: ${RETURN_VAL}"
fi

# Misc recovery for system
sleep 20
