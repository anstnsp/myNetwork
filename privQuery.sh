

echo "################### privateData One Query ###################"
docker exec cli peer chaincode query -C mychannel -n hcc-cc-many -c '{"Args":["queryPrivData", "CAR111"]}'