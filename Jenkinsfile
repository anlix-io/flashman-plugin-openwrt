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

        ##
        ## Replace .config default variables with custom provided externally
        ##

        DEFAULT_FLASHMAN_KEYS_PATH=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_KEYS_PATH)
        CUSTOM_FLASHMAN_KEYS_PATH=\"CONFIG_FLASHMAN_KEYS_PATH=\\\"${env.WORKSPACE}/\$REPO\\\"\"
        sed -i '/'\$DEFAULT_FLASHMAN_KEYS_PATH'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_KEYS_PATH >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_SERVER_ADDR)
        CUSTOM_FLASHMAN_SERVER_ADDR=\"CONFIG_FLASHMAN_SERVER_ADDR=\\\"${env.FLASHMANSERVERADDR}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_SERVER_ADDR'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WIFI_SSID=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WIFI_SSID)
        CUSTOM_FLASHMAN_WIFI_SSID=\"CONFIG_FLASHMAN_WIFI_SSID=\\\"${env.FLASHMANSSIDPREFIX}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_WIFI_SSID'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WIFI_SSID >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WIFI_PASSWD=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WIFI_PASSWD)
        CUSTOM_FLASHMAN_WIFI_PASSWD=\"CONFIG_FLASHMAN_WIFI_PASSWD=\\\"${env.FLASHMANWIFIPASS}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_WIFI_PASSWD'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WIFI_PASSWD >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WIFI_CHANNEL=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WIFI_CHANNEL)
        CUSTOM_FLASHMAN_WIFI_CHANNEL=\"CONFIG_FLASHMAN_WIFI_CHANNEL=\\\"${env.FLASHMANWIFICHANNEL}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_WIFI_CHANNEL'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WIFI_CHANNEL >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_RELEASE_ID=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_RELEASE_ID)
        CUSTOM_FLASHMAN_RELEASE_ID=\"CONFIG_FLASHMAN_RELEASE_ID=\\\"${env.FLASHMANRELEASEID}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_RELEASE_ID'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_RELEASE_ID >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_CLIENT_ORG=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_CLIENT_ORG)
        CUSTOM_FLASHMAN_CLIENT_ORG=\"CONFIG_FLASHMAN_CLIENT_ORG=\\\"${env.FLASHMANCLIENTORG}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_CLIENT_ORG'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_CLIENT_ORG >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_NTP_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_NTP_SERVER_ADDR)
        CUSTOM_NTP_SERVER_ADDR=\"CONFIG_NTP_SERVER_ADDR=\\\"${env.FLASHMANNTPADDR}\\\"\"
        sed -i -e '/'\$DEFAULT_NTP_SERVER_ADDR'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_NTP_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WAN_PROTO_PPPOE=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WAN_PROTO_PPPOE)
        DEFAULT_FLASHMAN_PPPOE_USER=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_PPPOE_USER)
        DEFAULT_FLASHMAN_PPPOE_PASSWD=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_PPPOE_PASSWD)
        DEFAULT_FLASHMAN_PPPOE_SERVICE=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_PPPOE_SERVICE)
        DEFAULT_FLASHMAN_WAN_PROTO_DHCP=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WAN_PROTO_DHCP)

        if [ \"${env.FLASHMANWANPROTO}\" == \"pppoe\" ]
        then
          CUSTOM_FLASHMAN_WAN_PROTO_PPPOE=\"CONFIG_FLASHMAN_WAN_PROTO_PPPOE=y\"
          CUSTOM_FLASHMAN_PPPOE_USER=\"CONFIG_FLASHMAN_PPPOE_USER=\\\"${env.FLASHMANPPPOEUSER}\\\"\"
          CUSTOM_FLASHMAN_PPPOE_PASSWD=\"CONFIG_FLASHMAN_PPPOE_PASSWD=\\\"${env.FLASHMANPPPOEPASS}\\\"\"
          CUSTOM_FLASHMAN_PPPOE_SERVICE=\"CONFIG_FLASHMAN_PPPOE_SERVICE=\\\"${env.FLASHMANPPPOESERVICE}\\\"\"
          CUSTOM_FLASHMAN_WAN_PROTO_DHCP=\"# CONFIG_FLASHMAN_WAN_PROTO_DHCP is not set\"
        else
          CUSTOM_FLASHMAN_WAN_PROTO_DHCP=\"CONFIG_FLASHMAN_WAN_PROTO_DHCP=y\"
          CUSTOM_FLASHMAN_WAN_PROTO_PPPOE=\"# CONFIG_FLASHMAN_WAN_PROTO_PPPOE is not set\"
          CUSTOM_FLASHMAN_PPPOE_USER=\"# CONFIG_FLASHMAN_PPPOE_USER is not set\"
          CUSTOM_FLASHMAN_PPPOE_PASSWD=\"# CONFIG_FLASHMAN_PPPOE_PASSWD is not set\"
          CUSTOM_FLASHMAN_PPPOE_SERVICE=\"# CONFIG_FLASHMAN_PPPOE_SERVICE is not set\"
        fi
        sed -i -e '/'\$DEFAULT_FLASHMAN_WAN_PROTO_PPPOE'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WAN_PROTO_PPPOE >> ${env.WORKSPACE}/\$REPO/.config

        sed -i -e '/'\$DEFAULT_FLASHMAN_PPPOE_USER'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_PPPOE_USER >> ${env.WORKSPACE}/\$REPO/.config

        sed -i -e '/'\$DEFAULT_FLASHMAN_PPPOE_PASSWD'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_PPPOE_PASSWD >> ${env.WORKSPACE}/\$REPO/.config

        sed -i -e '/'\$DEFAULT_FLASHMAN_PPPOE_SERVICE'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_PPPOE_SERVICE >> ${env.WORKSPACE}/\$REPO/.config
        
        sed -i -e '/'\$DEFAULT_FLASHMAN_WAN_PROTO_DHCP'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WAN_PROTO_DHCP >> ${env.WORKSPACE}/\$REPO/.config


        DEFAULT_FLASHMAN_WAN_MTU=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WAN_MTU)
        CUSTOM_FLASHMAN_WAN_MTU=\"CONFIG_FLASHMAN_WAN_MTU=\\\"${env.FLASHMANWANMTU}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_WAN_MTU'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WAN_MTU >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_AUTH_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_AUTH_SERVER_ADDR)
        CUSTOM_FLASHMAN_AUTH_SERVER_ADDR=\"CONFIG_FLASHMAN_AUTH_SERVER_ADDR=\\\"${env.AUTHSERVERADDR}\\\"\"
        sed -i -e '/'\$DEFAULT_FLASHMAN_AUTH_SERVER_ADDR'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_AUTH_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config
        
        DEFAULT_FLASHMAN_USE_AUTH_SERVER=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_USE_AUTH_SERVER)

        if [ \"${env.AUTHENABLESERVER}\" == \"true\" ]
        then
          CUSTOM_FLASHMAN_USE_AUTH_SERVER=\"CONFIG_FLASHMAN_USE_AUTH_SERVER=y\"
        else
          CUSTOM_FLASHMAN_USE_AUTH_SERVER=\"# CONFIG_FLASHMAN_USE_AUTH_SERVER is not set\"
        fi

        sed -i -e '/'\$DEFAULT_FLASHMAN_USE_AUTH_SERVER'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_USE_AUTH_SERVER >> ${env.WORKSPACE}/\$REPO/.config
        

        DEFAULT_ZABBIX_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_ZABBIX_SERVER_ADDR)
        CUSTOM_ZABBIX_SERVER_ADDR=\"CONFIG_ZABBIX_SERVER_ADDR=\\\"${env.ZABBIXSERVERADDR}\\\"\"
        sed -i -e '/'\$DEFAULT_ZABBIX_SERVER_ADDR'/d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_ZABBIX_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config
        
        ##
        ## End of replace variables section
        ##

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