#!/bin/bash

# import env
# . env.sh
source $(dirname "$0")/env.sh

PARM=$1

verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
    echo
    exit 1
  fi
}

# 환경변수 설정
setGlobals() {
  PEER=$1
  ORG=$2
  CORE_PEER_LOCALMSPID=${ORG}MSP
  CORE_PEER_TLS_ROOTCERT_FILE=$PEER_CERT_FILE_COMMON_DIR/${ORG}Organization/org${ORG}/peers/peer$PEER/tls/ca.crt
  CORE_PEER_MSPCONFIGPATH=${PEER_CERT_FILE_COMMON_DIR}/${ORG}Organization/org${ORG}/admin/msp
  CORE_PEER_ADDRESS=peer$PEER.org$ORG.com:7051
}


# 채널생성
createChannel() {
  echo
  echo "================================== Create Channel =================================="
  echo
  echo "sleep 15"
  sleep 5
  set -x
  peer channel create -o $ORDERER_ENDPOINT -c $CHANNEL_NAME -f $CHANNEL_TX_FILE --tls true --cafile $ORDERER_CA >&log.txt
  res=$?
  set +x #명령어 실행 후 명령어 echo로 출력 
  cat log.txt
  verifyResult $res "Channel Creation failed"
  echo "========================== Channel '$CHANNEL_NAME' created ==========================="
  echo
}

# 채널조인
joinChannel() {
  for org in $PEER_ORGS; do
    for ((peer_num=0;peer_num<$NUM_PEERS;peer_num++)); do
      joinChannelCommend $peer_num $org
        sleep $SLEEP_TIME
      echo
    done
  done
}

# 피어채널조인
joinChannelCommend() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  echo "=================== peer${PEER}.org${ORG} joinning start to '$CHANNEL_NAME' ==================="
  set -x
  peer channel join -b $CHANNEL_NAME.block >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "peer${PEER}.org${ORG}.com channel join failed"
  echo "==================== peer${PEER}.org${ORG} joined channel '$CHANNEL_NAME' ====================="
  echo
  echo
}

# 앵커피어설정
updateAnchorPeers() {
  for org in $PEER_ORGS; 
  do
    updateAnchorPeerCommend $org
    sleep $SLEEP_TIME
  done
}

# 앵커피어설정명령
updateAnchorPeerCommend() {
  PEER=0
  ORG=$1
  setGlobals $PEER $ORG

  echo "====================== peer${PEER}.org${ORG} Anchor peer setting start ======================"
  set -x
  peer channel update -o $ORDERER_ENDPOINT -c $CHANNEL_NAME -f /channel-artifacts/${ORG}MSP_anchors.tx --tls true --cafile $ORDERER_CA >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "peer${PEER}.org${ORG}.com anchor peer update failed"
  echo "============== peer${PEER}.org${ORG} Anchor peer setting complete '$CHANNEL_NAME' ============="
  echo
  echo
  echo
}

# 체인코드 인스톨
chaincodeInstall() {
  for org in $PEER_ORGS; do
    for ((peer_num=0; peer_num < ${NUM_PEERS}; peer_num++)); do
      chaincodeInstallCommend $peer_num $org
        sleep $SLEEP_TIME
      echo
    done
  done
}

# 체인코드 인스톨명령
chaincodeInstallCommend() {
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

# 체인코드 instantiate
chaincodeInstantiate() {
  setGlobals 0 ${PEER_ORGS[0]}

  echo "================================ instantiate start ================================="
  set -x
  peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["initLedger"]}' >&log.txt
  #peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["init"]}' -P "OR ('hccMSP.peer', 'lotMSP.peer', 'swtMSP.peer')" --collections-config /opt/gopath/src/github.com/chaincode/hcc-last-chaincode/collection_config.json >&log.txt
#  peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["init"]}' --collections-config /opt/gopath/src/github.com/chaincode/marbles02_private/collections_config.json >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode instantiate failed"
  echo "================================ instantiate finished =============================="
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

# NodeJS체인코드 인스톨
NodeJSchaincodeInstall() {
  for org in $PEER_ORGS; do
    for ((peer_num=0;peer_num<$PEERS_NUM;peer_num++)); do
      NodeJSchaincodeInstallCommend $peer_num $org
        sleep $SLEEP_TIME
      echo
    done
  done
}

# NodeJS체인코드 인스톨명령
NodeJSchaincodeInstallCommend() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  echo "============= peer${peer_num}.org${org} chaincode installing start to '$CHANNEL_NAME' ============="
  set -x
  peer chaincode install -n $CC_NAME_NODE -v ${CC_VERSION_NODE} -l $CC_LANGUAGE_NODE -p ${CC_SRC_PATH_NODE} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "NodeJSChaincode installation on peer${PEER}.org${ORG} has failed"
  echo "============== peer${peer_num}.org${org} chaincode install complete '$CHANNEL_NAME' ==============="
  echo
  echo
}

# NodeJS체인코드 instantiate
NodeJSchaincodeInstantiate() {
  setGlobals 0 ${PEER_ORGS[0]}

  echo "================================ instantiate start ================================="
  set -x
  #peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["init"]}' >&log.txt
  peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME_NODE -l $CC_LANGUAGE_NODE -v $CC_VERSION_NODE -c '{"Args":["initLedger"]}' --collections-config /opt/gopath/src/github.com/chaincode/hcc-last-chaincode/collection_config.json >&log.txt
#  peer chaincode instantiate -o $ORDERER_ENDPOINT --tls true --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l $CC_LANGUAGE -v $CC_VERSION -c '{"Args":["init"]}' --collections-config /opt/gopath/src/github.com/chaincode/marbles02_private/collections_config.json >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "NodeJSChaincode instantiate failed"
  echo "================================ instantiate finished =============================="
  echo
  echo
}

if [ "${PARM}" == "all" ]; then
  createChannel
  joinChannel
  updateAnchorPeers
  chaincodeInstall
  chaincodeInstantiate
  echo "  All setting finished!!"
  echo
elif [ "${PARM}" == "create-channel" ]; then
  createChannel
  echo "  Create channel finished!!"
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
elif [ "${PARM}" == "chaincode-instantiate" ]; then
  chaincodeInstantiate
  echo "  Chaincode instantiating finished"
  echo
elif [ "${PARM}" == "chaincode-upgrade" ]; then
  chaincodeUpgrade
  echo "  Chaincode upgrade finished"
  echo
elif [ "${PARM}" == "NodeJSchaincode-install" ]; then
  NodeJSchaincodeInstall
  echo "All peers NodeJSchaincode install finished!! "
  echo
elif [ "${PARM}" == "NodeJSchaincode-instantiate" ]; then
  NodeJSchaincodeInstantiate
  echo "NodeJSChaincode instantiate finished"
  echo 
else
  echo "Please input the arg"
  exit 1
fi