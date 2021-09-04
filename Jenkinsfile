// Declarative //
pipeline {
    agent any
  
  stages {
    stage('install')
    - echo starting build
    - echo docker build
    - echo push docker image
    - echo installing terraform
    - echo install -y yum-utils
    - yum-config-manager --add-repo hhtps://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    - yum -y install terraform
    - echo terraform init
    - echo terraform plan
    - echo terraform apply -auto-approve
  }

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing..'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}
// Script //
node {
    stage('Build') {
        echo 'Building....'
    }
    stage('Test') {
        echo 'Building....'
    }
    stage('Deploy') {
        echo 'Deploying....'
    }
}

stages {
}
