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

function main {
   echo "Beginning registering orderer and peer identities ..."
   registerIdentities
   getCACerts
   enrollPeer
   printPeerOrg
   
   echo "Finished registers orderer and peer identities"
}



function updateConfig() {
  echo "############################################################################"
  echo "##### update config start  #########"
  echo "############################################################################"

export CHANNEL_NAME=$CHANNEL_NAME
export ORDERER_CA=$ORDERER_CA

#config블럭 가져옴
peer channel fetch config config_block.pb -o orderer0.orgorderer.com:7050 -c mychannel --tls --cafile /crypto-config/ordererOrganization/orgorderer/orderers/orderer0.orgorderer.com/msp/tlscacerts/rca-orgorderer-com-7054.pem
#가져온 컨피그블럭에서 필요한 거만 추려서 json으로 디코딩 
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"lg":.[1]}}}}}' config.json lg.json > modified_config.json

#config.json 을 다시 pb타입으로 인코딩 
configtxlator proto_encode --input config.json --type common.Config --output config.pb

#조직 추가한 modified_config.json도 pb로 인코딩 
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

#기존 config와 수정된 config의 차분 계산 해서 addorg_update.pb파일로 떨굼. 
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output addorg_update.pb

#차분계산한 addorg_update.pb파일을 json으로 디코딩 
configtxlator proto_decode --input addorg_update.pb --type common.ConfigUpdate | jq . > addorg_update.json

#처음에 config블럭 가져올때 뺏던 헤더 다시 삽입
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat addorg_update.json)'}}}' | jq . > addorg_update_in_envelope.json

#헤더까지 집어넣어서 완성된 json을 마지막으로 pb로 인코딩
configtxlator proto_encode --input addorg_update_in_envelope.json --type common.Envelope --output addorg_update_in_envelope.pb

#해당 권한에 맞게 위에서 만든 pb파일에 서명. 
peer channel signconfigtx -f addorg_update_in_envelope.pb


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
      # Generate client TLS cert and key pair for the peer
      #genClientTLSCert $PEER/opt/gopath/src/github.com/hyperledger/_NAME $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE
      # Generate client TLS cert and key pair for the peer CLI
      #genClientTLSCert $PEER_NAME /$DATA/tls/$PEER_NAME-cli-client.crt /$DATA/tls/$PEER_NAME-cli-client.key


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


#   *************************fabric-ca-client enroll --help [flag]***********************************************
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

function makeConfigTxYaml {
   {
   echo "
################################################################################
#
#   Section: Organizations
#
#   - This section defines the different organizational identities which will
#   be referenced later in the configuration.
#
################################################################################
Organizations:"

   for ORG in $PEER_ORGS; do
      printPeerOrg $ORG 0
   done

   echo "
################################################################################
#
#   SECTION: Capabilities
#
#   - This section defines the capabilities of fabric network. This is a new
#   concept as of v1.1.0 and should not be utilized in mixed networks with
#   v1.0.x peers and orderers.  Capabilities define features which must be
#   present in a fabric binary for that binary to safely participate in the
#   fabric network.  For instance, if a new MSP type is added, newer binaries
#   might recognize and validate the signatures from this type, while older
#   binaries without this support would be unable to validate those
#   transactions.  This could lead to different versions of the fabric binaries
#   having different world states.  Instead, defining a capability for a channel
#   informs those binaries without this capability that they must cease
#   processing transactions until they have been upgraded.  For v1.0.x if any
#   capabilities are defined (including a map with all capabilities turned off)
#   then the v1.0.x peer will deliberately crash.
#
################################################################################
Capabilities:
    # Channel capabilities apply to both the orderers and the peers and must be
    # supported by both.
    # Set the value of the capability to true to require it.
    Channel: &ChannelCapabilities
        # V1.3 for Channel is a catchall flag for behavior which has been
        # determined to be desired for all orderers and peers running at the v1.3.x
        # level, but which would be incompatible with orderers and peers from
        # prior releases.
        # Prior to enabling V1.3 channel capabilities, ensure that all
        # orderers and peers on a channel are at v1.3.0 or later.
        
        V1_3: true
        V1_1: true
        
    # Orderer capabilities apply only to the orderers, and may be safely
    # used with prior release peers.
    # Set the value of the capability to true to require it.
    Orderer: &OrdererCapabilities
        # V1.1 for Orderer is a catchall flag for behavior which has been
        # determined to be desired for all orderers running at the v1.1.x
        # level, but which would be incompatible with orderers from prior releases.
        # Prior to enabling V1.1 orderer capabilities, ensure that all
        # orderers on a channel are at v1.1.0 or later.
        V1_1: true

    # Application capabilities apply only to the peer network, and may be safely
    # used with prior release orderers.
    # Set the value of the capability to true to require it.
    Application: &ApplicationCapabilities
        # V1.3 for Application enables the new non-backwards compatible
        # features and fixes of fabric v1.3.
        V1_3: true
        # V1.2 for Application enables the new non-backwards compatible
        # features and fixes of fabric v1.2 (note, this need not be set if
        # later version capabilities are set)
        V1_2: false
        # V1.1 for Application enables the new non-backwards compatible
        # features and fixes of fabric v1.1 (note, this need not be set if
        # later version capabilities are set).
        V1_1: false

################################################################################
#
#   SECTION: Application
#
#   This section defines the values to encode into a config transaction or
#   genesis block for application related parameters
#
################################################################################
Application: &ApplicationDefaults

    # Organizations is the list of orgs which are defined as participants on
    # the application side of the network
    Organizations:

    # Policies defines the set of policies at this level of the config tree
    # For Application policies, their canonical path is
    #   /Channel/Application/<PolicyName>
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: \"ANY Readers\"
        Writers:
            Type: ImplicitMeta
            Rule: \"ANY Writers\"
        Admins:
            Type: ImplicitMeta
            Rule: \"ANY Admins\"

    Capabilities:
        <<: *ApplicationCapabilities
"
   echo "
################################################################################
#
#   SECTION: Orderer
#
#   - This section defines the values to encode into a config transaction or
#   genesis block for orderer related parameters
#
################################################################################
Orderer: &OrdererDefaults

  # Orderer Type: The orderer implementation to start
  # Available types are \"solo\" and \"kafka\"
    # Orderer Type: The orderer implementation to start
    # Available types are \"solo\" and \"kafka\"
    OrdererType: solo
    Addresses:"

   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $((COUNT-1))
         echo "        - $ORDERER_HOST:7050"
         COUNT=$((COUNT+1))
      done
   done

   echo "
    # Batch Timeout: The amount of time to wait before creating a batch
    BatchTimeout: 1s

    # Batch Size: Controls the number of messages batched into a block
    BatchSize:

      # Max Message Count: The maximum number of messages to permit in a batch
      MaxMessageCount: 10

      # Absolute Max Bytes: The absolute maximum number of bytes allowed for
      # the serialized messages in a batch.
      AbsoluteMaxBytes: 99 MB

      # Preferred Max Bytes: The preferred maximum number of bytes allowed for
      # the serialized messages in a batch. A message larger than the preferred
      # max bytes will result in a batch larger than preferred max bytes.
      PreferredMaxBytes: 512 KB

    Kafka:
        # Brokers: A list of Kafka brokers to which the orderer connects
        # NOTE: Use IP:port notation
        Brokers:
            - 127.0.0.1:9092
      
    # Organizations is the list of orgs which are defined as participants on
    # the orderer side of the network
    Organizations:

    # Policies defines the set of policies at this level of the config tree
    # For Orderer policies, their canonical path is
    #   /Channel/Orderer/<PolicyName>
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: \"ANY Readers\"
        Writers:
            Type: ImplicitMeta
            Rule: \"ANY Writers\"
        Admins:
            Type: ImplicitMeta
            Rule: \"MAJORITY Admins\"
        # BlockValidation specifies what signatures must be included in the block
        # from the orderer for the peer to validate it.
        BlockValidation:
            Type: ImplicitMeta
            Rule: \"ANY Writers\"


################################################################################
#
#   CHANNEL
#
#   This section defines the values to encode into a config transaction or
#   genesis block for channel related parameters.
#
################################################################################
Channel: &ChannelDefaults
    # Policies defines the set of policies at this level of the config tree
    # For Channel policies, their canonical path is
    #   /Channel/<PolicyName>
    Policies:
        # Who may invoke the 'Deliver' API
        Readers:
            Type: ImplicitMeta
            Rule: \"ANY Readers\"
        # Who may invoke the 'Broadcast' API
        Writers:
            Type: ImplicitMeta
            Rule: \"ANY Writers\"
        # By default, who may modify elements at this config level
        Admins:
            Type: ImplicitMeta
            Rule: \"MAJORITY Admins\"

    # Capabilities describes the channel level capabilities, see the
    # dedicated Capabilities section elsewhere in this file for a full
    # description
    Capabilities:
        <<: *ChannelCapabilities

################################################################################
#
#   Profile
#
#   - Different configuration profiles may be encoded here to be specified
#   as parameters to the configtxgen tool
#
################################################################################
Profiles:

    TwoOrgsOrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:"
            
   for ORG in $ORDERER_ORGS; do
      printf "                  - *${ORG}"
   done
   echo "
            Capabilities:
                <<: *OrdererCapabilities
        Consortiums:
            SampleConsortium:
                Organizations:"
    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        echo "                - *${ORG}"
    done

   echo "
    TwoOrgsChannel:
        Consortium: SampleConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:"
    for ORG in $PEER_ORGS; do
        initOrgVars $ORG
        echo "                - *${ORG}"
    done
    echo "
            Capabilities:
              <<: *ApplicationCapabilities


   "
   } > /etc/hyperledger/fabric/configtx.yaml
   # Copy it to the data directory to make debugging easier
   cp /etc/hyperledger/fabric/configtx.yaml /addorg-artifacts/
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
function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "Generating orderer genesis block at $GENESIS_BLOCK_FILE"

  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  configtxgen -profile TwoOrgsOrdererGenesis -channelID $SYSTEM_CHANNEL_NAME -outputBlock $GENESIS_BLOCK_FILE
  
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate orderer genesis block"
    exit 1
  fi

  echo "Generating channel configuration transaction at $CHANNEL_TX_FILE"
  configtxgen -profile TwoOrgsChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate channel configuration transaction"
    exit 1
  fi

  for ORG in $PEER_ORGS; do
     initOrgVars $ORG
     echo "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
     configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
                 -channelID $CHANNEL_NAME -asOrg $ORG
     if [ "$?" -ne 0 ]; then
        echo "Failed to generate anchor peer update for $ORG"
        exit 1
     fi
  done
}

set -e

SDIR=$(dirname "$0")
source $SDIR/add-env.sh

main
