
#추가할 조직의 crypto-material(인증서,configtx.yaml 만들어야함.)




function main() {
  startRootCA
  getCertificate
  docker exec cli /scripts/script.sh "config-update"
  sleep  5
  peerAndCliUp
  joinChannel
  installChaincode
}

#추가할 조직의 CA시작 
function startRootCA() {

  echo "############################################################################"
  echo "##### startRootCA  #########"
  echo "############################################################################"

  cd compose-files 
  docker-compose -f docker-compose-addorg.yaml up -d rca.orglg.com 
  cd ..
}

#CA로부터 인증서 발급 
function getCertificate() {


  echo "############################################################################"
  echo "##### getCertificate  #########"
  echo "############################################################################"
 
  if [ -d "addorg-artifacts" ]; then
    sudo rm -rf ./addorg-artifacts
  fi
  mkdir addorg-artifacts

  cd compose-files 
  docker-compose -f docker-compose-addorg.yaml up -d addorg-setup addorg-cli
  cd ..
  wait 
}

function wait() {
  
  local FILENAME=channel-artifacts/${PEER_ORGS}.json
  # local FILENAME=configtx.yaml 
  while true; do 
    echo "Waiting for generaing ${PEER_ORGS}.json ..." 
    if [ -f ${FILENAME} ]; then
      break
    fi 
    sleep 1 
  done
  
}

function peerAndCliUp() {

  cd compose-files 
  docker-compose -f docker-compose-addorg.yaml up -d peer0.orglg.com peer1.orglg.com addorg-cli
  res=$?
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates and channel-artifacts..."
    exit 1
  fi
  echo

  cd ../

}

# 피어 채널 조인
function joinChannel() {
  docker exec addorg-cli /scripts/addorg-script.sh "join-channel"
}

# 채인코드 인스톨
function installChaincode() {
  docker exec addorg-cli /scripts/addorg-script.sh "chaincode-install"
}



set -e

SDIR=$(dirname "$0")
source $SDIR/scripts/addorg-env.sh

main
