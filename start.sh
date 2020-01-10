cd compose-files 
docker-compose up -d rca.orgorderer.com rca.orgnaver.com rca.orgkakao.com setup 

echo "sleep 10s..."
sleep 10s 

docker-compose up -d orderer0.orgorderer.com peer0.orgnaver.com peer1.orgnaver.com 

cd ..
