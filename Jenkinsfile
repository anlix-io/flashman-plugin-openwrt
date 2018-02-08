#!/usr/bin/env groovy

properties([
  parameters([
    string(name: 'TARGETMODEL', defaultValue: 'tl-wr940n-v4'),
    string(name: 'FLASHMANPUBKEY', defaultValue: 'public key'),
    string(name: 'FLASHMANSERVERADDR', defaultValue: 'flashman.example.com'),
    string(name: 'FLASHMANSSIDPREFIX', defaultValue: 'Flashman-AP-'),
    string(name: 'FLASHMANWIFIPASS', defaultValue: ''),
    string(name: 'FLASHMANWIFICHANNEL', defaultValue: 'auto'),
    string(name: 'FLASHMANRELEASEID', defaultValue: '9999-flm'),
    string(name: 'FLASHMANCLIENTORG', defaultValue: 'anlix'),
    string(name: 'FLASHMANNTPADDR', defaultValue: 'a.st1.ntp.br'),
    string(name: 'FLASHMANWANPROTO', defaultValue: 'dhcp'),
    string(name: 'FLASHMANWANMTU', defaultValue: '1500'),
    string(name: 'FLASHMANPPPOEUSER', defaultValue: 'flashman-user'),
    string(name: 'FLASHMANPPPOEPASS', defaultValue: 'Flashman!'),
    string(name: 'FLASHMANPPPOESERVICE', defaultValue: 'auto'),
    string(name: 'ZABBIXSENDNETDATA', defaultValue: 'true'),
    string(name: 'ZABBIXSERVERADDR', defaultValue: 'zabbix.example.com'),
    string(name: 'AUTHENABLESERVER', defaultValue: 'false'),
    string(name: 'AUTHSERVERADDR', defaultValue: 'auth.example.com'),
    string(name: 'AUTHCLIENTSECRET', defaultValue: 'secret'),
  ])
])

node {
    checkout scm
    
    stage('Build') {
      echo "Building...."
      
      // OpenWRT buildroot setup
      sh """
        DIFFCONFIG=\$(ls ${env.WORKSPACE}/diffconfigs | grep ${params.TARGETMODEL} | head -1)
        REPO=\$(echo \$DIFFCONFIG | awk -F _ '{print \$1}')
        BRANCH=\$(echo \$DIFFCONFIG | awk -F _ '{print \$2}')
        COMMIT=\$(echo \$DIFFCONFIG | awk -F _ '{print \$3}')
        TARGET=\$(echo \$DIFFCONFIG | awk -F _ '{print \$4}')
        PROFILE=\$(echo \$DIFFCONFIG | awk -F _ '{print \$5}')

        if [ ! -d ${env.WORKSPACE}/\$REPO ]
        then
          git clone https://github.com/anlix-io/\$REPO.git -b \$BRANCH
        fi

        cp ${env.WORKSPACE}/diffconfigs/\$DIFFCONFIG ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_KEYS_PATH=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_KEYS_PATH)
        CUSTOM_FLASHMAN_KEYS_PATH=\"CONFIG_FLASHMAN_KEYS_PATH=\\\"${env.WORKSPACE}/\$REPO\\\"\"

        sed -i -e 's,'\$DEFAULT_FLASHMAN_KEYS_PATH','\$CUSTOM_FLASHMAN_KEYS_PATH',g' ${env.WORKSPACE}/\$REPO/.config

        cd ${env.WORKSPACE}/\$REPO

        git checkout \$COMMIT

        ./scripts/feeds update -a
        ./scripts/feeds install -a

        make defconfig

        cp -r ${env.WORKSPACE}/flashman-plugin ${env.WORKSPACE}/\$REPO/package/utils/
        mkdir -p ${env.WORKSPACE}/\$REPO/files/etc
        cp ${env.WORKSPACE}/banner ${env.WORKSPACE}/\$REPO/files/etc/

        echo ${params.FLASHMANPUBKEY} > ${env.WORKSPACE}/\$REPO/id_rsa_flashman.pub

        if [ ! -f ${env.WORKSPACE}/\$REPO/download_done ]
        then
          make download
          echo done > ${env.WORKSPACE}/\$REPO/download_done
        fi

        make package/utils/flashman-plugin/clean
        make -j \$((\$(nproc) + 1))
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