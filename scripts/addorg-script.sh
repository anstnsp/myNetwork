#!/bin/bash

#추가할 조직의 crypto-material(인증서,configtx.yaml 만들어야함.)

source $(dirname "$0")/addorg-env.sh

PARM=$1



function verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
    echo
    exit 1
  fi
}

# 환경변수 설정
function setGlobals() {
  PEER=$1
  ORG=$2
  CORE_PEER_LOCALMSPID=${ORG}MSP
  CORE_PEER_TLS_ROOTCERT_FILE=$PEER_CERT_FILE_COMMON_DIR/${ORG}Organization/org${ORG}/peers/peer$PEER/tls/ca.crt
  CORE_PEER_MSPCONFIGPATH=${PEER_CERT_FILE_COMMON_DIR}/${ORG}Organization/org${ORG}/admin/msp
  CORE_PEER_ADDRESS=peer$PEER.org$ORG.com:7051
}



# 채널조인
function joinChannel() {
  for org in $PEER_ORGS; do
    for ((peer_num=0;peer_num<$NUM_PEERS;peer_num++)); do
      joinChannelCommand $peer_num $org
        sleep $SLEEP_TIME
      echo
    done
  done
}

# 피어채널조인
function joinChannelCommand() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  echo "=================== peer${PEER}.org${ORG} joinning start to '$CHANNEL_NAME' ==================="
  set -x
  peer channel join -b $CHANNEL_NAME.block 
  res=$?
  set +x
  verifyResult $res "peer${PEER}.org${ORG}.com channel join failed"
  echo "==================== peer${PEER}.org${ORG} joined channel '$CHANNEL_NAME' ====================="
  echo
  echo
}


# 체인코드 인스톨
function chaincodeInstall() {
  for org in $PEER_ORGS; do
    for ((peer_num=0; peer_num < ${NUM_PEERS}; peer_num++)); do
      chaincodeInstallCommand $peer_num $org
        sleep $SLEEP_TIME
      echo
    done
  done
}

# 체인코드 인스톨명령
function chaincodeInstallCommand() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  echo "============= peer${peer_num}.org${org} chaincode installing start to '$CHANNEL_NAME' ============="
  set -x
  peer chaincode install -n $CC_NAME -v ${CC_VERSION} -l $CC_LANGUAGE -p ${CC_SRC_PATH} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on peer${PEER}.org${ORG} has failed"
  echo "============== peer${peer_num}.org${org} chaincode install complete '$CHANNEL_NAME' ==============="
  echo
  echo
}

# 체인코드 upgrade
chaincodeUpgrade() {
  setGlobals 0 ${PEER_ORGS[0]}

  echo "================================ upgrade start ================================="
  set -x
  #peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["init"]}' >&log.txt
  peer chaincode upgrade -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["init"]}' --collections-config /opt/gopath/src/github.com/chaincode/hcc-chaincode-pdc/collection_config.json >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode upgrade failed"
  echo "================================ upgrade finished =============================="
  echo
  echo
}


if [ "${PARM}" == "all" ]; then
  joinChannel
  chaincodeInstall
  echo "  All setting finished!!"
  echo
elif [ "${PARM}" == "join-channel" ]; then
  joinChannel
  echo "  All peers channel joining finished!!"
  echo
elif [ "${PARM}" == "update-anchor-peers" ]; then
  updateAnchorPeers
  echo "  Each org's anchor peer setting finished!!"
  echo
elif [ "${PARM}" == "chaincode-install" ]; then
  chaincodeInstall
  echo "  All peers chaincode installing finished!!"
  echo
else
  echo "Please input the arg"
  exit 1
fi


