#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script does the following:
# registers orderer and peer identities with intermediate fabric-ca-servers
#

#추가 될 조직의 인증서 발급부터 org.json 생성까지. 
function main {
   echo "Beginning registering orderer and peer identities ..."
   registerIdentities
   getCACerts
   enrollPeer
   printPeerOrg
   
   echo "Finished registers orderer and peer identities"
}

# Enroll the CA administrator
function enrollCAAdmin {

   waitPort "$CA_NAME to start" 20 $CA_HOST_PORT
   echo "Enrolling with $CA_NAME as bootstrap identity ..."
   export FABRIC_CA_CLIENT_HOME=$HOME/cas/$CA_NAME  #/etc/hyperledger/fabric-ca/crypto/cas/rca-orderer , /etc/hyperledger/fabric-ca/crypto/cas/rca-naver , /root/cas/rca-orderer
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE # /crypto-config/rca-certs/rca.org${ORG}.com-cert.pem
   # fabric-ca-client affiliation add ${ORG}
   fabric-ca-client enroll -d  -u https://$CA_ADMIN_USER_PASS@$CA_HOST_PORT 
}

function registerIdentities {
   echo "Registering identities ..."
   registerPeerIdentities
}
#   *************************fabric-ca-client register [flag]***********************************************
#       --caname string                  Name of CA
#       --csr.cn string                  The common name field of the certificate signing request
#       --csr.hosts stringSlice          A list of space-separated host names in a certificate signing request
#       --csr.names stringSlice          A list of comma-separated CSR names of the form <name>=<value> (e.g. C=CA,O=Org1)
#       --csr.serialnumber string        The serial number in a certificate signing request
#   -d, --debug                          Enable debug level logging
#       --enrollment.attrs stringSlice   A list of comma-separated attribute requests of the form <name>[:opt] (e.g. foo,bar:o
#       --enrollment.label string        Label to use in HSM operations
#       --enrollment.profile string      Name of the signing profile to use in issuing the certificate
#       --enrollment.type string         The type of enrollment request (default "x509")
#   -H, --home string                    Client's home directory (default "/root/.fabric-ca-client")
#       --id.affiliation string          The identity's affiliation
#       --id.attrs stringSlice           A list of comma-separated attributes of the form <name>=<value> (e.g. foo=foo1,bar=ba
#       --id.maxenrollments int          The maximum number of times the secret can be reused to enroll (default CA's Max Enro
#       --id.name string                 Unique name of the identity
#       --id.secret string               The enrollment secret for the identity being registered
#       --id.type string                 Type of identity being registered (e.g. 'peer, app, user') (default "client")
#   -M, --mspdir string                  Membership Service Provider directory (default "msp")
#   -m, --myhost string                  Hostname to include in the certificate signing request during enrollment (default "17
#   -a, --revoke.aki string              AKI (Authority Key Identifier) of the certificate to be revoked
#   -e, --revoke.name string             Identity whose certificates should be revoked
#   -r, --revoke.reason string           Reason for revocation
#   -s, --revoke.serial string           Serial number of the certificate to be revoked
#       --tls.certfiles stringSlice      A list of comma-separated PEM-encoded trusted certificate files (e.g. root1.pem,root2
#       --tls.client.certfile string     PEM-encoded certificate file when mutual authenticate is enabled
#       --tls.client.keyfile string      PEM-encoded key file when mutual authentication is enabled
#   -u, --url string                     URL of fabric-ca-server (default "http://localhost:7054")
#   ********************************************************************************************************************


# Register any identities associated with a peer
function registerPeerIdentities {
   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      # fabric-ca-client affiliation add ${ORG}
      # fabric-ca-client affiliation list 
      enrollCAAdmin
      fabric-ca-client affiliation add ${ORG}
      fabric-ca-client affiliation list 
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $((COUNT-1))
         echo "Registering $PEER_NAME with $CA_NAME"
         #PEER 등록 (Register peer)
         fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer  --id.affiliation ${ORG} --caname ${CA_NAME} --csr.names C=KR,O=${ORG},ST=Seoul 
         COUNT=$((COUNT+1))
      done
      echo "Registering admin identity with $CA_NAME"
      # The admin identity has the "admin" attribute which is added to ECert by default
      #조직의 admin등록 (Register admin)
      fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.type client  --id.affiliation ${ORG} --id.attrs "hf.Registrar.Roles=admin,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" --caname ${CA_NAME} --csr.names C=KR,O=${ORG},ST=Seoul
      echo "Registering user identity with $CA_NAME"
      #client 등록 (Register client) << dapp에서는 admin이나 client 쓰면됨.  
      fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS --id.type user  --id.affiliation ${ORG} --caname ${CA_NAME} --csr.names C=KR,O=${ORG},ST=Seoul
   done
}

function getCACerts {
   echo "@@@@@@@@@@@@@@@@Getting CA certificates ...@@@@@@@@@@@@@@@@"
   echo "CA로부터 CA인증서 가져오기 시작..."
   for ORG in $ORGS; do
      initOrgVars $ORG
      echo "Getting CA certs for organization $ORG and storing in $ORG_MSP_DIR"
      echo "$ORG조직의 CA인증서를 얻어서 $ORG_MSP_DIR에 저장한다."
      export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      fabric-ca-client getcacert -d -u https://$CA_HOST_PORT -M $ORG_MSP_DIR
      finishMSPSetup $ORG_MSP_DIR
      # If ADMINCERTS is true, we need to enroll the admin now to populate the admincerts directory
      if [ $ADMINCERTS ]; then
         switchToAdminIdentity
      fi
   done
}

function enrollPeer {
  
  for ORG in $PEER_ORGS; do
    for (( i=0; i<$NUM_PEERS; i++ ));do
      initPeerVars $ORG $i     #ex) initPeerVars naver 0 
      export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      fabric-ca-client enroll -d  --csr.names C=KR,O=${ORG},ST=Seoul --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/$ORG/peer$i/tls --csr.hosts $PEER_HOST

      # Copy the TLS key and cert to the appropriate place
      mkdir -p $TLSDIR
      cp /tmp/$ORG/peer$i/tls/signcerts/* $TLSDIR/server.crt  #$CORE_PEER_TLS_CERT_FILE
      cp /tmp/$ORG/peer$i/tls/keystore/* $TLSDIR/server.key   #$CORE_PEER_TLS_KEY_FILE
      cp $CA_CHAINFILE $TLSDIR/ca.crt 
      rm -rf /tmp/$ORG/peer$i/tls


      # Enroll the peer to get an enrollment certificate and set up the core's local MSP directory
      fabric-ca-client enroll -d  --csr.names C=KR,O=${ORG},ST=Seoul -u $ENROLLMENT_URL -M $MSPDIR
      # *_sk를 server.key 로 변경 
      mv  $MSPDIR/keystore/* $MSPDIR/keystore/server.key
      
      finishMSPSetup $MSPDIR 
      copyAdminCert $MSPDIR $PEER_HOST
      makeConfigOU $ORG $MSPDIR
      makeConfigOU $ORG $ORG_MSP_DIR  
      echo "## enrollPeer${i} End ##"
    done
  done
}


# printOrg
function printOrg {
   echo "
  - &$ORG

    Name: $ORG

    # ID to load the MSP definition as
    ID: $ORG_MSP_ID

    # MSPDir is the filesystem path which contains the MSP configuration
    MSPDir: $ORG_MSP_DIR"
}



# printPeerOrg <ORG> <COUNT>
function printPeerOrg {
  
   initPeerVars $ORG 0
  #  printOrg
  {
   echo "
Organizations:
  - &$ORG

      Name: $ORG

      # ID to load the MSP definition as
      ID: $ORG_MSP_ID

      # MSPDir is the filesystem path which contains the MSP configuration
      MSPDir: $ORG_MSP_DIR
      # Policies defines the set of policies at this level of the config tree
      # For organization policies, their canonical path is usually
      #   /Channel/<Application|Orderer>/<OrgName>/<PolicyName>
      Policies:
          Readers:
              Type: Signature
              Rule: \"OR('${ORG}MSP.admin','${ORG}MSP.peer',  '${ORG}MSP.client')\"
          Writers:
              Type: Signature
              Rule: \"OR('${ORG}MSP.admin', '${ORG}MSP.client')\"
          Admins:
              Type: Signature
              Rule: \"OR('${ORG}MSP.admin')\"
      AnchorPeers:
        # AnchorPeers defines the location of peers which can be used
        # for cross org gossip communication.  Note, this value is only
        # encoded in the genesis block in the Application section context
        - Host: $PEER_HOST"
  echo "          Port: 7051"
  }  > /etc/hyperledger/fabric/configtx.yaml
   # Copy it to the data directory to make debugging easier
   cp /etc/hyperledger/fabric/configtx.yaml /addorg-artifacts
   cd /addorg-artifacts
   export FABRIC_CFG_PATH=$PWD 
   configtxgen -printOrg $ORG > /channel-artifacts/$ORG.json

}

# $1 = 조직명 , $2 MSP디렉토리 
# EX) makeConfigOU naver /msp 
function makeConfigOU() {
   {
      echo "
NodeOUs:
   Enable: true
   ClientOUIdentifier:
      Certificate: "cacerts/rca-org$1-com-7054.pem"
      OrganizationalUnitIdentifier: "client"
   AdminOUIdentifier:
      Certificate: "cacerts/rca-org$1-com-7054.pem"
      OrganizationalUnitIdentifier: "admin"
   PeerOUIdentifier:
      Certificate: "cacerts/rca-org$1-com-7054.pem"
      OrganizationalUnitIdentifier: "peer"
   OrdererOUIdentifier:
      Certificate: "cacerts/rca-org$1-com-7054.pem"
      OrganizationalUnitIdentifier: "orderer"
      
   "
   } > /etc/hyperledger/fabric/config.yaml 
   cp /etc/hyperledger/fabric/config.yaml $2
}


set -e

SDIR=$(dirname "$0")
source $SDIR/addorg-env.sh

main
