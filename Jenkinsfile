#!/usr/bin/env groovy

properties([
  parameters([
    string(name: 'TESTE', defaultValue: 'bar' ),
    string(name: 'FOO', defaultValue: 'bar' ),
   ])
])

node {
    checkout scm
    
    stage('Build') {
        echo "Building...."
        echo "Chosen variable value is: ${params.TESTE}"
        echo "Chosen variable value is: ${params.FOO}"
    }
    stage('Test') {
        echo "Building...."
    }
    stage('Deploy') {
        echo "Deploying...."
    }
}