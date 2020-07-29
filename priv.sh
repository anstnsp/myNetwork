
export CAR=$(echo -n "{\"carNumber\":\"CAR111\",\"price\":444}" | base64)
# echo $CAR
docker exec -e "CORE_PEER_LOCALMSPID=naverMSP" -e "CORE_PEER_MSPCONFIGPATH=/crypto-config/naverOrganization/orgnaver/admin/msp" cli peer chaincode invoke -o orderer0.orgorderer.com:7050 --tls true --cafile /crypto-config/rca-certs/rca.orgorderer.com-cert.pem -C mychannel -n hcc-cc-many -c '{"Args":["createPrivData"]}' --transient "{\"car\":\"$CAR\"}" 


