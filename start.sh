# cd compose-files 
# docker-compose up -d rca.orgorderer.com rca.orgnaver.com rca.orgkakao.com setup 

# echo "sleep 10s..."
# sleep 10s 

# docker-compose up -d orderer0.orgorderer.com peer0.orgnaver.com peer1.orgnaver.com peer0.orgkakao.com peer1.orgkakao.com 

# cd ..


set -e

source ./scripts/env.sh


function printHelp() {

  echo
  echo "==========================================================================================="
  echo
  echo "Usage: "
  echo "  hcc-dev.sh <mode>"
  echo "  <mode> - one of '-start', '-up', '-down', '-generate', '-channel', '-join', -upgrade"
  echo "           '-anchor', '-install', '-instantiate'"
  echo "    -> '-start : Bring up the network with docker-compose up and set all blockchain system'"
  echo "    -> '-up' : Bring up the network with docker-compose up"
  echo "    -> '-down' : Clear the network with docker-compose down"
  echo "     -> '-remove' : Remove artifacts and crypto-material with docker-compose down"
  echo "    -> '-generate' : Generate required certificates and genesis block"
  echo "    -> '-channel' : Create channel in blockchain system"
  echo "    -> '-join' : Join all peers in channel"
  echo "    -> '-anchor' : Set all Anchor peers"
  echo "    -> '-install' : Install chaincode to all peers"
  echo "    -> '-instantiate' : Instantiate chaincode to channel"
  echo
  echo
  echo "example: "
  echo
  echo "     hcc-dev.sh -start"
  echo "     hcc-dev.sh -generate"
  echo "     hcc-dev.sh -up"
  echo "     hcc-dev.sh -down"
  echo "     hcc-dev.sh -remove"
  echo "     hcc-dev.sh -channel"
  echo "     hcc-dev.sh -join"
  echo "     hcc-dev.sh -anchor"
  echo "     hcc-dev.sh -install"
  echo "     hcc-dev.sh -instantiate"
  echo "     hcc-dev.sh -upgrade"
  echo "     hcc-dev.sh -nodeinstall"
  echo "     hcc-dev.sh -nodeinstantiate"
  echo
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
    docker-compose --project-name nice up -d rca.org${ORG}.com 
  done 
  
  sleep 2s
  docker-compose --project-name nice up  -d setup 
  echo " " 

  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates and channel-artifacts..."
    exit 1
  fi
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
      docker-compose --project-name nice up -d peer${i}.org${ORG}.com 
    done
  done

  #ORDERER_ORGS
  for ORG in $ORDERER_ORGS; do
    for (( i=0; i<$NUM_ORDERERS; i++ ));do
      docker-compose --project-name nice up -d orderer${i}.org${ORG}.com 
    done
  done
  docker-compose --project-name nice up -d cli 
  cd ../
}

# 블록체인 다운
function networkDown() {  
  cd ./compose-files
  docker-compose --project-name nice down 
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
  set +x 
  res=$? 
  echo $res 
    docker network prune 
    docker system prune 
    docker volume prune 




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