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
      //echo "Chosen variable value is: ${params.TESTE}"
      //echo "Chosen variable value is: ${params.FOO}"
      //sh "echo 12345678 > test.txt"

      //OpenWRT buildroot setup
      sh '''
        git clone https://www.github.com/openwrt/openwrt -b v17.01.4
        cd ${env.WORKSPACE}/openwrt
        ${env.WORKSPACE}/scripts/feeds update -a
        ${env.WORKSPACE}/scripts/feeds install -a
        cp ${env.WORKSPACE}/diffconfig-lede-snapshot ${env.WORKSPACE}/openwrt
        make defconfig
        make download
        make -j 4
      '''
    }
    stage('Deploy') {
      echo "Deploying...."
      //def server = Artifactory.server "artifactory-anlix-io"
      //def uploadSpec = '''{
      //  "files": [
      //    {
      //      "pattern": "test.txt",
      //      "target": "firmwares/anlix/"
      //    }
      // ]
      //}'''
      //server.upload(uploadSpec)
    }
}