#!/usr/bin/env groovy

properties([
  parameters([
    string(name: 'TESTE', defaultValue: 'bar' )
   ])
])

node {
    checkout scm
    
    stage('Build') {
        echo "Building...."
        echo "Chosen variable value is: ${params.TESTE}"
    }
    stage('Test') {
        echo "Building...."
    }
    stage('Deploy') {
        echo "Deploying...."
    }
}