#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# The following variables describe the topology and may be modified to provide
# different organization names or the number of peers in each peer organization.
#

# Name of the docker-compose network
NETWORK=nice

# Names of the orderer organizations
ORDERER_ORGS="orderer"

# Names of the peer organizations
PEER_ORGS="naver kakao"

# Number of peers in each peer organization
NUM_PEERS=2

#
# The remainder of this file contains variables which typically would not be changed.
#
# All org names
ORGS="$ORDERER_ORGS $PEER_ORGS"

# Set to true to populate the "admincerts" folder of MSPs
ADMINCERTS=true

# Number of orderer nodes
NUM_ORDERERS=1

# The remainder of this file contains variables which typically would not be changed.
GENESIS_BLOCK_FILE=/channel-artifacts/genesis.block

# The path to a channel transaction
CHANNEL_TX_FILE=/channel-artifacts/channel.tx

# Name of test channel
CHANNEL_NAME=mychannel

# Name of system channel 
SYSTEM_CHANNEL_NAME=syschannel 

#go버전 최신 체인코드 
CC_SRC_PATH=chaincode/fabcar/
# 체인코드 언어(GO)
CC_LANGUAGE=golang
# Orderer tls 인증서 경로
ORDERER_CA=/crypto-config/ordererOrganization/orgorderer/orderers/orderer0.orgorderer.com/msp/tlscacerts/rca-orgorderer-com-7054.pem

CC_NAME=hcc-cc-many
# 체인코드버젼
CC_VERSION=16.0
# sleep 함수 시간 설정
SLEEP_TIME=0.2
# ORDERER 엔드포인트
ORDERER_ENDPOINT=orderer0.orgorderer.com:7050
# PEER 인증서 공통 경로
PEER_CERT_FILE_COMMON_DIR=/crypto-config


# initOrgVars <ORG>
function initOrgVars {
   if [ $# -ne 1 ]; then
      echo "Usage: initOrgVars <ORG>"
      exit 1
   fi
   local ORG=$1

   # Root CA admin identity
   ROOT_CA_ADMIN_USER=admin
   ROOT_CA_ADMIN_PASS=adminpw
   ROOT_CA_ADMIN_USER_PASS=${ROOT_CA_ADMIN_USER}:${ROOT_CA_ADMIN_PASS}
   # Admin identity for the org
   ADMIN_NAME=admin-${ORG}  #ex) admin-orderer, admin-naver 
   ADMIN_PASS=adminpw
   # Typical user identity for the org
   USER_NAME=user1
   USER_PASS=${USER_NAME}pw

   ROOT_CA_CERTFILE=/crypto-config/${ORG}Organization/org${ORG}/ca/rca.org${ORG}.com-cert.pem
   #ANCHOR_TX_FILE=/root/data/${ORG}_anchors.tx
   ANCHOR_TX_FILE=/channel-artifacts/${ORG}MSP_anchors.tx
   ORG_MSP_ID=${ORG}MSP
   #ORG_MSP_DIR=/root/orgs/${ORG}/msp
   ORG_MSP_DIR=/crypto-config/${ORG}Organization/org${ORG}/msp
   ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/${ORG}_admin_cert.pem
   #ORG_ADMIN_CERT=/scripts/admincerts/${ORG}_admin_cert.pem
   ORG_ADMIN_HOME=/crypto-config/${ORG}Organization/org${ORG}/admin

   CA_NAME=rca-${ORG}
   local PORT=7054

   CA_HOST_PORT=rca.org${ORG}.com:${PORT}
   CA_CHAINFILE=$ROOT_CA_CERTFILE
   CA_ADMIN_USER_PASS=${ROOT_CA_ADMIN_USER}:${ROOT_CA_ADMIN_PASS}
}

# initOrdererVars <NUM>
function initOrdererVars {
   if [ $# -ne 2 ]; then
      echo "Usage: initOrdererVars <ORG> <NUM>"
      exit 1
   fi
   initOrgVars $1
   NUM=$2
   ORDERER_HOST=orderer${NUM}.org${ORG}.com
   ORDERER_NAME=orderer${NUM}
   ORDERER_PASS=orderer${NUM}pw
   #ORDERER_NAME_PASS=${ORDERER_NAME}:${ORDERER_PASS}
  #  MYHOME=/etc/hyperledger/orderer
   ENROLLMENT_URL=https://${ORDERER_NAME}:${ORDERER_PASS}@${CA_HOST_PORT}

   TLSDIR=/crypto-config/ordererOrganization/org${ORG}/orderers/$ORDERER_HOST/tls
   MSPDIR=/crypto-config/ordererOrganization/org${ORG}/orderers/$ORDERER_HOST/msp

}




# initPeerVars <ORG> <NUM>
function initPeerVars {
   if [ $# -ne 2 ]; then
      echo "Usage: initPeerVars <ORG> <NUM>: $*"
      exit 1
   fi   
   initOrgVars $1  #ex) initOrgVars naver  , initOrgVars orderer
   NUM=$2
   PEER_HOST=peer${NUM}.org${ORG}.com
   PEER_NAME=peer${NUM}_${ORG}
   PEER_PASS=peer${NUM}_${ORG}pw
   #PEER_NAME_PASS=${PEER_NAME}:${PEER_PASS}
   #PEER_LOGFILE=$LOGDIR/${PEER_NAME}.log
   ENROLLMENT_URL=https://${PEER_NAME}:${PEER_PASS}@${CA_HOST_PORT}
   TLSDIR=/crypto-config/${ORG}Organization/org${ORG}/peers/peer${NUM}/tls
   MSPDIR=/crypto-config/${ORG}Organization/org${ORG}/peers/peer${NUM}/msp 
# /crypto-config/peer0.orgnaver.comOrganization/orgpeer0.orgnaver.com/ca/rca.orgpeer0.orgnaver.com.com-cert.pem': open /crypto-config/peer0.orgnaver.comOrganization/orgpeer0.orgnaver.com/ca/rca.orgpeer0.orgnaver.com.com-cert.pem


}

# Wait for one or more files to exist
# Usage: dowait <what> <timeoutInSecs> <file> [<file> ...]
function dowait {
   if [ $# -lt 3 ]; then
      echo "Usage: dowait: $*"
      exit 1
   fi
   local what=$1
   local secs=$2
   shift 2
   local starttime=$(date +%s)
   for file in $*; do
      until [ -f $file ]; do
         echo "Waiting for $what ..."
         sleep 1
         if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
            echo "Failed waiting for $what ($file not found);"
            exit 1
         fi
      done
   done
   echo ""
}

# Wait for a process to begin to listen on a particular host and port
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
function waitPort {
   set +e
   local what=$1
   local secs=$2
   input=$3
   local host=${input%%:*}
   local port=${input##*:}
   echo $host "is waitport host "
   echo $port "is waitport port"

   nc -z $host $port > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo "Waiting for $what ..."
      local starttime=$(date +%s)
      while true; do
         sleep 1
         nc -z $host $port > /dev/null 2>&1
         if [ $? -eq 0 ]; then
            break
         fi
         if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
            echo "Failed waiting for $what"
            exit 1
         fi
         echo -n "."
      done
      echo ""
   fi
   set -e
}

# Create the TLS directories of the MSP folder if they don't exist.
# The fabric-ca-client should do this.
function finishMSPSetup {
   if [ $# -ne 1 ]; then
      echo "Usage: finishMSPSetup <targetMSPDIR>"
      exit 1
   fi
   if [ ! -d $1/tlscacerts ]; then
      mkdir $1/tlscacerts
      
      cp $1/cacerts/* $1/tlscacerts
   
      if [ -d $1/intermediatecerts ]; then
         mkdir $1/tlsintermediatecerts
         cp $1/intermediatecerts/* $1/tlsintermediatecerts
      fi
   fi
}

# Copy the org's admin cert into some target MSP directory
# This is only required if ADMINCERTS is enabled.
function copyAdminCert {
   if [ $# -ne 2 ]; then
      echo "Usage: copyAdminCert <targetMSPDIR>"
      exit 1
   fi

   dstDir=$1/admincerts
   local ORG=$2
   mkdir -p $dstDir
   dowait "$ORG administator to enroll" 60 $ORG_ADMIN_CERT
   cp $ORG_ADMIN_CERT $dstDir
}

# Switch to the current org's admin identity.  Enroll if not previously enrolled.
function switchToAdminIdentity {
   if [ ! -d $ORG_ADMIN_HOME ]; then
      dowait "$CA_NAME to start" 60 $CA_CHAINFILE
      echo "Enrolling admin '$ADMIN_NAME' with $CA_HOST_PORT ..."
      export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
      export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      fabric-ca-client enroll -d -u https://$ADMIN_NAME:$ADMIN_PASS@$CA_HOST_PORT
      # If admincerts are required in the MSP, copy the cert there now and to my local MSP also
      if [ $ADMINCERTS ]; then
         mkdir -p $(dirname "${ORG_ADMIN_CERT}")
         cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_CERT
         mkdir $ORG_ADMIN_HOME/msp/admincerts
         cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_HOME/msp/admincerts
         # local copy
         cp $ORG_ADMIN_HOME/msp/signcerts/* ${ORG_ADMIN_CERT}
      fi
   fi
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
}
