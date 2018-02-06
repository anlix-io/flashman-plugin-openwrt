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
      sh "echo 12345678 > test.txt"
    }
    stage('Test') {
      echo "Building...."
    }
    stage('Deploy') {
      echo "Deploying...."
      def server = Artifactory.server "artifactory-anlix-io"

      def uploadSpec = '''{
        "files": [
          {
            "pattern": "test.txt",
            "target": "firmwares/anlix/"
          }
       ]
      }'''
      server.upload(uploadSpec)
    }
}