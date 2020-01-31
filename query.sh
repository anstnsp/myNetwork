
echo "################### oldOrg Query ###################"

docker exec cli peer chaincode query -C mychannel -n hcc-cc-many -c '{"Args":["queryAllCars"]}'

echo "################### newOrg Query ###################"

docker exec addorg-cli peer chaincode query -C mychannel -n hcc-cc-many -c '{"Args":["queryAllCars"]}'
