#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e


# Initialize the root CA
fabric-ca-server init -b admin:adminpw 
#루트CA의 인증서를 보관할 폴더 생성. 
mkdir -p /crypto-config/rca-certs
mkdir -p /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/ca
# mkdir -p /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/tlsca

# Copy the root CA's signing certificate to the data directory to be used by others
cp $FABRIC_CA_SERVER_HOME/ca-cert.pem /crypto-config/rca-certs/${FABRIC_CA_SERVER_CSR_CN}-cert.pem
cp $FABRIC_CA_SERVER_HOME/ca-cert.pem /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/ca/${FABRIC_CA_SERVER_CSR_CN}-cert.pem
# cp $FABRIC_CA_SERVER_HOME/tls-cert.pem /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/tls/tls${FABRIC_CA_SERVER_CSR_CN}-cert.pem

FABRIC_ORGS="orderer naver kakao"
# Add the custom orgs
for o in $FABRIC_ORGS; do
   aff=$aff"\n   $o: []"
done
aff="${aff#\\n   }"
sed -i "/affiliations:/a \\   $aff" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# TEST_EXPIRY="expiry: ${TEST_EXPIRY}"
# echo $TEST_EXPIRY
# sed -i "260,280s/expiry: 8760h/$TEST_EXPIRY/" $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml


# TLS_EXPIRY="expiry: ${TLS_EXPIRY}h"
# sed -i "280,300s/expiry: 8760h/$TLS_EXPIRY/" $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# Start the root CA
fabric-ca-server start  

# function test {
  
#   if [ ! -d /crypto-config/rca-certs ]; then 
#     mkdir -p /crypto-config/rca-certs 
#   fi 
  
#   if [ ! -d /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/ca ]; then 
#     mkdir /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/ca
#   fi 

#   cp /var/hyperledger/production/ca/naverca-server/ca-cert.pem  /crypto-config/rca-certs/${FABRIC_CA_SERVER_CSR_CN}-cert.pem
#   cp /var/hyperledger/production/ca/ordererca-server/ca-cert.pem /crypto-config/${FABRIC_CA_SERVER_CA_NAME:4}Organization/org${FABRIC_CA_SERVER_CA_NAME:4}/ca/${FABRIC_CA_SERVER_CSR_CN}-cert.pem

# }

