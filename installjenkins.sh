#!/bin/bash



install(){
    #update env
    sudo apt update
    sudo apt upgrade -y
    sudo apt-get install curl

    #install jdk
    sudo apt-get purge openjdk* -y
    sudo apt install openjdk-17-jdk -y

    #GPG key Jenkins
    sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins

    sudo systemctl start jenkins
    sudo systemctl enable jenkins
}


main(){
if systemctl list-units --type=service | grep -q jenkins.service; then
    echo "Installed"
else
    echo "Installing"
    install
fi
}

main