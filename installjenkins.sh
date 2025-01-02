#!/bin/bash

#update env
sudo apt update
sudo apt upgrade -y
sudo apt-get install curl

#install jdk
sudo apt install openjdk-11-jdk -y

#GPG key Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update


sudo apt install jenkins -y

sudo systemctl start jenkins
sudo systemctl enable jenkins