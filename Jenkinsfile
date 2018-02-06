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

      // OpenWRT buildroot setup
      sh """
        if [ ! -d ${env.WORKSPACE}/openwrt ]
        then
          git clone https://www.github.com/openwrt/openwrt -b v17.01.4
        fi
        cp ${env.WORKSPACE}/diffconfig-lede-snapshot ${env.WORKSPACE}/openwrt

        cd ${env.WORKSPACE}/openwrt
        ./scripts/feeds update -a
        ./scripts/feeds install -a

        make defconfig
        make download
        make V=s
      """
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