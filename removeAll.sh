#!/bin/bash

docker rm -f $(docker ps -aq) 

docker network prune 
docker system prune 
docker volume prune 

docker ps -a 

#sudo rm -r org* 
#sudo rm -r ca-*
#sudo rm -r channel-artifacts
sudo rm -r crypto-config 
sudo rm -r /var/hyperledger
sudo rm -r channel-artifacts
