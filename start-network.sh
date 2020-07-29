#!/bin/bash
set -e

source ./scripts/env.sh


function printHelp() {

  echo
  echo "==========================================================================================="
  echo
  echo "Usage: "
  echo "  start-network.sh <mode>"
  echo "  <mode> - one of '-start', '-up', '-down', '-generate', '-channel', '-join', -upgrade"
  echo "           '-anchor', '-install', '-instantiate'"
  echo "    -> '-start     : 인증서발급부터 체인코드인스턴시에이트 까지 END-TO-END'"
  echo "    -> '-up'       : 네트워크 시작 "
  echo "    -> '-down'     : 네트워크 중지"
  echo "    -> '-remove'   : 인증서를 삭제하고 네트워크 중지 및 도커볼륨 삭제 "
  echo "    -> '-generate' : CA서버로부터 인증서발급 및 채널artifacts 생성"
  echo "    -> '-channel'  : 채널 생성"
  echo "    -> '-join'     : 모든피어를 채널에 조인"
  echo "    -> '-anchor'   : 앵커피어 셋팅 "
  echo "    -> '-install'  : 모든피어에 체인코드 설치"
  echo "    -> '-instantiate' : 체인코드 인스턴시에이트 "
  echo
  echo
  echo "example: "
  echo
  echo "     start-network.sh -start"
  echo "     start-network.sh -generate"
  echo "     start-network.sh -up"
  echo "     start-network.sh -down"
  echo "     start-network.sh -remove"
  echo "     start-network.sh -channel"
  echo "     start-network.sh -join"
  echo "     start-network.sh -anchor"
  echo "     start-network.sh -install"
  echo "     start-network.sh -instantiate"
  echo "     start-network.sh -upgrade"
  echo "     start-network.sh -nodeinstall"
  echo "     start-network.sh -nodeinstantiate"
  echo ""
  echo "     *** 구동 시 순서 ***"
  echo "     1)start-network.sh -generate" 
  echo "     2)start-network.sh -up"
  echo "     3)start-network.sh -channel"
  echo "     4)start-network.sh -join"
  echo "     5)start-network.sh -anchor"
  echo "     6)start-network.sh -install"
  echo "     7)start-network.sh -instantiate"
  echo "     *** 한번에 전부 시작 ***"
  echo "     1)start-network.sh -start"
  echo "==========================================================================================="
  echo

}


# 모든 블록체인 네트워크 구성(노드생성부터 채널생성, 조인 체인코드 install 등등)
function blockChainAllSet() {
  docker exec cli /scripts/script.sh "all"
}

function generateCertsAndChannelArtifacts() {

  echo
  echo "############################################################################"
  echo "##### Generate certificates using FABRIC-CA AND channel-artifacts  #########"
  echo "############################################################################"


  if [ -d "crypto-config" ]; then
    rm -rf ./crypto-config
  fi
  set -x

  cd compose-files 
  for ORG in $ORGS; do 
    echo " rca.org${ORG}.com start..." 
    docker-compose up -d rca.org${ORG}.com 
  done 
  
  sleep 2s
  docker-compose up  -d setup
  echo " " 
  

  # $$는 현재 스크립트의 PID를 나타냄 
  # $!는 최근에 실행한 백그라운드(비동기) 명령의 PID
  # wait PID 하면 해당 PID가 끝날때까지 기다림. 
  # $? 최근에 실행된 명령어, 함수, 스크립트 자식의 종료 상태
  waitGen 
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates and channel-artifacts..."
    exit 1
  fi
  docker-compose up  -d cli
  docker exec cli /scripts/script.sh "generate-channel-artifacts"
  echo

  cd ../
}

function networkUp() {

  echo "############################################################################"
  echo "##### peer and orderer up  #########"
  echo "############################################################################"

  cd compose-files 

  #PEER_ORGS
  for ORG in $PEER_ORGS; do
    for (( i=0; i<$NUM_PEERS; i++ ));do
      docker-compose up -d peer${i}.org${ORG}.com 
    done
  done

  #ORDERER_ORGS
  for ORG in $ORDERER_ORGS; do
    for (( i=0; i<$NUM_ORDERERS; i++ ));do
      docker-compose up -d orderer${i}.org${ORG}.com 
    done
  done

  cd ../
}

# 블록체인 다운
function networkDown() {  
  cd ./compose-files
  docker-compose  down 
  docker stop $(docker ps -aq)
  docker rm $(docker ps -aq)
  docker rmi $(docker images dev-* -q)
#  rm -rf ./channel-artifacts ./crypto-config
}

# 도커관련 제거 및 인증서,아티팩트 삭제 
function removeVolume() {
    set -x
  if [ -d "crypto-config" ]; then 
    sudo rm -r crypto-config
  fi 
  if [ -d "/var/hyperledger" ]; then 
    sudo rm -r /var/hyperledger
  fi 
  if [ -d "channel-artifacts" ]; then 
    sudo rm -r channel-artifacts
  fi 
  docker rm -f $(docker ps -aq)
  docker rmi $(docker images dev-* -q)
  rm -rf configtx.yaml
  docker network prune 
  docker system prune 
  docker volume prune 
  set +x 
  res=$? 
  echo $res 


}

#generate를 통해 configtx.yaml파일 생성까지 확인 
function waitGen() {
  
  set +e 
  set +x 
  cd ..
  local FILENAME=./configtx.yaml 
  # local FILENAME=configtx.yaml 
  while true; do 
    echo "Waiting for generaing configtx.yaml ..." 
    if [ -f ${FILENAME} ]; then
      break
    fi 
    sleep 1 
  done
  cd compose-files
  
}

# 채널생성
function createChannel() {
  docker exec cli /scripts/script.sh "create-channel"
}

# 모든 피어 채널 조인
function joinChannel() {
  docker exec cli /scripts/script.sh "join-channel"
}

# 모든 org 앵커피어 설정
function updateAnchorPeers() {
  docker exec cli /scripts/script.sh "update-anchor-peers"
}

# 채인코드 인스톨
function installChaincode() {
  docker exec cli /scripts/script.sh "chaincode-install"
}

# 채인코드 instantiate
function instantiate() {
  docker exec cli /scripts/script.sh "chaincode-instantiate"
}

# 채인코드 upgrade
function upgrade() {
  docker exec cli /scripts/script.sh "chaincode-upgrade"
}




if [ "$1" == "-start" ]; then
  generateCertsAndChannelArtifacts
  networkUp
  blockChainAllSet
elif [ "$1" == "-up" ]; then
  networkUp
elif [ "$1" == "-down" ]; then ## Clear the network
  networkDown
elif [ "$1" == "-remove" ]; then 
  removeVolume
  networkDown
elif [ "$1" == "-z" ]; then 
  zookeeperUp
elif [ "$1" == "-k" ]; then 
  kafkaUp
elif [ "$1" == "-generate" ]; then ## Generate Certs, Artifacts
  generateCertsAndChannelArtifacts
elif [ "$1" == "-channel" ]; then
  createChannel
elif [ "$1" == "-join" ]; then
  joinChannel
elif [ "$1" == "-anchor" ]; then
  updateAnchorPeers
elif [ "$1" == "-install" ]; then
  installChaincode
elif [ "$1" == "-instantiate" ]; then
  instantiate
elif [ "$1" == "-upgrade" ]; then
  upgrade
elif [ "$1" == "-nodeinstall" ]; then 
  NodeJSinstallChaincode
elif [ "$1" == "-nodeinstantiate" ]; then
  NodeJSinstantiateChaincode
else
  printHelp
  exit 1
fi
