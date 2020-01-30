
#추가할 조직의 crypto-material(인증서,configtx.yaml 만들어야함.)

function startRootCA() {
  cd compose-files 
  docker-compose -f docker-compose-addorg.yaml up -d rca.orglg.com add-setup
  cd ..
}

function addedOrgPeerUp() {

  echo
  echo "############################################################################"
  echo "##### Generate certificates using FABRIC-CA AND channel-artifacts  #########"
  echo "############################################################################"


  if [ -d "addorg-artifacts" ]; then
    rm -rf ./addorg-artifacts
  fi
  set -x
  mkdir addorg-artifacts
  cd compose-files 

  docker-compose -f docker-compose-addorg.yaml up -d peer0.orglg.com peer1.orglg.com addorg-cli


  echo " " 
  # $$는 현재 스크립트의 PID를 나타냄 
  # $!는 최근에 실행한 백그라운드(비동기) 명령의 PID
  # wait PID 하면 해당 PID가 끝날때까지 기다림. 
  # $? 최근에 실행된 명령어, 함수, 스크립트 자식의 종료 상태

  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates and channel-artifacts..."
    exit 1
  fi
  echo

  cd ../
}

startRootCA
sleep 5
docker exec cli /scripts/script.sh "config-update"
sleep 5
addedOrgPeerUp

