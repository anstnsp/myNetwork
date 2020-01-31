
#docker 설치
echo "###install docker###"
sudo wget -qO- https://get.docker.com | sh

#docker-compose 설치 
echo "### install docker-compose ###"
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose


echo " docker -v"
docker -v 

echo " docker-compose -v"
docker-compose -v 





