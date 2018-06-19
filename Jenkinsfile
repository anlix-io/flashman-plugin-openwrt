#!/usr/bin/env groovy

properties([
  parameters([
    string(name: 'TARGETMODEL', defaultValue: 'tl-wr940n-v4'),
    string(name: 'OUTPUTIMGMODEL', defaultValue: 'tl-wr940n'),
    string(name: 'OUTPUTIMGMODELVER', defaultValue: 'v4'),
    string(name: 'OUTPUTIMGVENDOR', defaultValue: 'tp-link'),
    string(name: 'FLASHMANPUBKEY', defaultValue: 'public key'),
    string(name: 'FLASHMANSERVERADDR', defaultValue: 'flashman.example.com'),
    string(name: 'FLASHMANSSIDSUFFIX', defaultValue: 'lastmac'),
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
    string(name: 'ARTIFACTORYUSER', defaultValue: ''),
    string(name: 'ARTIFACTORYPASS', defaultValue: ''),
    string(name: 'MQTTPORT', defaultValue: '1883')
  ])
])

node() {
    checkout scm
    
    stage('Build') {
      echo "Building...."
      
      // OpenWRT buildroot setup
      sh """
        DIFFCONFIG=\$(ls ${env.WORKSPACE}/diffconfigs | grep ${params.TARGETMODEL} | head -1)
        REPO=\$(echo \$DIFFCONFIG | awk -F '~' '{print \$1}')
        BRANCH=\$(echo \$DIFFCONFIG | awk -F '~' '{print \$2}')
        COMMIT=\$(echo \$DIFFCONFIG | awk -F '~' '{print \$3}')
        TARGET=\$(echo \$DIFFCONFIG | awk -F '~' '{print \$4}')
        PROFILE=\$(echo \$DIFFCONFIG | awk -F '~' '{print \$5}')

        if [ ! -d ${env.WORKSPACE}/\$REPO ]
        then
          git clone https://github.com/anlix-io/\$REPO.git -b \$BRANCH
        fi

        cd ${env.WORKSPACE}/\$REPO

        git fetch
        git checkout \$COMMIT

        ./scripts/feeds update -a
        ./scripts/feeds install -a

        cp -r ${env.WORKSPACE}/flashman-plugin ${env.WORKSPACE}/\$REPO/package/utils/
        mkdir -p ${env.WORKSPACE}/\$REPO/files/etc
        cp ${env.WORKSPACE}/banner ${env.WORKSPACE}/\$REPO/files/etc/
        cp ${env.WORKSPACE}/login.sh ${env.WORKSPACE}/\$REPO/package/base-files/files/bin/
        chmod +x ${env.WORKSPACE}/\$REPO/package/base-files/files/bin/login.sh

        ## Refresh targets
        touch target/linux/*/Makefile

        cp ${env.WORKSPACE}/diffconfigs/\$DIFFCONFIG ${env.WORKSPACE}/\$REPO/.config

        ##
        ## Replace .config default variables with custom provided externally
        ##

        DEFAULT_FLASHMAN_KEYS_PATH=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_KEYS_PATH)
        CUSTOM_FLASHMAN_KEYS_PATH=\"CONFIG_FLASHMAN_KEYS_PATH=\\\"${env.WORKSPACE}/\$REPO\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_KEYS_PATH',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_KEYS_PATH >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_SERVER_ADDR)
        CUSTOM_FLASHMAN_SERVER_ADDR=\"CONFIG_FLASHMAN_SERVER_ADDR=\\\"${params.FLASHMANSERVERADDR}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_SERVER_ADDR',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_SSID_SUFFIX_NONE=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_SSID_SUFFIX_NONE || echo '^\$')
        DEFAULT_FLASHMAN_SSID_SUFFIX_LASTMAC=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_SSID_SUFFIX_LASTMAC || echo '^\$')

        if [ \"${params.FLASHMANSSIDSUFFIX}\" = \"none\" ]
        then
          CUSTOM_FLASHMAN_SSID_SUFFIX_NONE=\"CONFIG_FLASHMAN_SSID_SUFFIX_NONE=y\"
          CUSTOM_FLASHMAN_SSID_SUFFIX_LASTMAC=\"# CONFIG_FLASHMAN_SSID_SUFFIX_LASTMAC is not set\"
        else
          CUSTOM_FLASHMAN_SSID_SUFFIX_NONE=\"# CONFIG_FLASHMAN_SSID_SUFFIX_NONE is not set\"
          CUSTOM_FLASHMAN_SSID_SUFFIX_LASTMAC=\"CONFIG_FLASHMAN_SSID_SUFFIX_LASTMAC=y\"
        fi

        sed -i -e '\\,'\$DEFAULT_FLASHMAN_SSID_SUFFIX_NONE',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_SSID_SUFFIX_NONE >> ${env.WORKSPACE}/\$REPO/.config
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_SSID_SUFFIX_LASTMAC',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_SSID_SUFFIX_LASTMAC >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WIFI_SSID=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WIFI_SSID)
        CUSTOM_FLASHMAN_WIFI_SSID=\"CONFIG_FLASHMAN_WIFI_SSID=\\\"${params.FLASHMANSSIDPREFIX}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_WIFI_SSID',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WIFI_SSID >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WIFI_PASSWD=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WIFI_PASSWD)
        CUSTOM_FLASHMAN_WIFI_PASSWD_STR=\'${params.FLASHMANWIFIPASS}\'
        CUSTOM_FLASHMAN_WIFI_PASSWD=\"CONFIG_FLASHMAN_WIFI_PASSWD=\\\"\$CUSTOM_FLASHMAN_WIFI_PASSWD_STR\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_WIFI_PASSWD',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WIFI_PASSWD >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WIFI_CHANNEL=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WIFI_CHANNEL)
        CUSTOM_FLASHMAN_WIFI_CHANNEL=\"CONFIG_FLASHMAN_WIFI_CHANNEL=\\\"${params.FLASHMANWIFICHANNEL}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_WIFI_CHANNEL',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WIFI_CHANNEL >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_RELEASE_ID=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_RELEASE_ID)
        CUSTOM_FLASHMAN_RELEASE_ID=\"CONFIG_FLASHMAN_RELEASE_ID=\\\"${params.FLASHMANRELEASEID}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_RELEASE_ID',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_RELEASE_ID >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_CLIENT_ORG=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_CLIENT_ORG)
        CUSTOM_FLASHMAN_CLIENT_ORG=\"CONFIG_FLASHMAN_CLIENT_ORG=\\\"${params.FLASHMANCLIENTORG}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_CLIENT_ORG',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_CLIENT_ORG >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_NTP_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_NTP_SERVER_ADDR)
        CUSTOM_NTP_SERVER_ADDR=\"CONFIG_NTP_SERVER_ADDR=\\\"${params.FLASHMANNTPADDR}\\\"\"
        sed -i -e '\\,'\$DEFAULT_NTP_SERVER_ADDR',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_NTP_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_WAN_PROTO_PPPOE=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WAN_PROTO_PPPOE || echo '^\$')
        DEFAULT_FLASHMAN_PPPOE_USER=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_PPPOE_USER || echo '^\$')
        DEFAULT_FLASHMAN_PPPOE_PASSWD=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_PPPOE_PASSWD || echo '^\$')
        DEFAULT_FLASHMAN_PPPOE_SERVICE=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_PPPOE_SERVICE || echo '^\$')
        DEFAULT_FLASHMAN_WAN_PROTO_DHCP=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WAN_PROTO_DHCP || echo '^\$')

        if [ \"${params.FLASHMANWANPROTO}\" = \"pppoe\" ]
        then
          CUSTOM_FLASHMAN_WAN_PROTO_PPPOE=\"CONFIG_FLASHMAN_WAN_PROTO_PPPOE=y\"
          CUSTOM_FLASHMAN_PPPOE_USER=\"CONFIG_FLASHMAN_PPPOE_USER=\\\"${params.FLASHMANPPPOEUSER}\\\"\"
          CUSTOM_FLASHMAN_PPPOE_PASSWD=\"CONFIG_FLASHMAN_PPPOE_PASSWD=\\\"${params.FLASHMANPPPOEPASS}\\\"\"
          CUSTOM_FLASHMAN_PPPOE_SERVICE=\"CONFIG_FLASHMAN_PPPOE_SERVICE=\\\"${params.FLASHMANPPPOESERVICE}\\\"\"
          CUSTOM_FLASHMAN_WAN_PROTO_DHCP=\"# CONFIG_FLASHMAN_WAN_PROTO_DHCP is not set\"
        else
          CUSTOM_FLASHMAN_WAN_PROTO_DHCP=\"CONFIG_FLASHMAN_WAN_PROTO_DHCP=y\"
          CUSTOM_FLASHMAN_WAN_PROTO_PPPOE=\"# CONFIG_FLASHMAN_WAN_PROTO_PPPOE is not set\"
          CUSTOM_FLASHMAN_PPPOE_USER=\"# CONFIG_FLASHMAN_PPPOE_USER is not set\"
          CUSTOM_FLASHMAN_PPPOE_PASSWD=\"# CONFIG_FLASHMAN_PPPOE_PASSWD is not set\"
          CUSTOM_FLASHMAN_PPPOE_SERVICE=\"# CONFIG_FLASHMAN_PPPOE_SERVICE is not set\"
        fi
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_WAN_PROTO_PPPOE',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WAN_PROTO_PPPOE >> ${env.WORKSPACE}/\$REPO/.config

        sed -i -e '\\,'\$DEFAULT_FLASHMAN_PPPOE_USER',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_PPPOE_USER >> ${env.WORKSPACE}/\$REPO/.config

        sed -i -e '\\,'\$DEFAULT_FLASHMAN_PPPOE_PASSWD',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_PPPOE_PASSWD >> ${env.WORKSPACE}/\$REPO/.config

        sed -i -e '\\,'\$DEFAULT_FLASHMAN_PPPOE_SERVICE',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_PPPOE_SERVICE >> ${env.WORKSPACE}/\$REPO/.config
        
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_WAN_PROTO_DHCP',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WAN_PROTO_DHCP >> ${env.WORKSPACE}/\$REPO/.config


        DEFAULT_FLASHMAN_WAN_MTU=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_WAN_MTU)
        CUSTOM_FLASHMAN_WAN_MTU=\"CONFIG_FLASHMAN_WAN_MTU=\\\"${params.FLASHMANWANMTU}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_WAN_MTU',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_WAN_MTU >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_AUTH_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_AUTH_SERVER_ADDR)
        CUSTOM_FLASHMAN_AUTH_SERVER_ADDR=\"CONFIG_FLASHMAN_AUTH_SERVER_ADDR=\\\"${params.AUTHSERVERADDR}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_AUTH_SERVER_ADDR',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_AUTH_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_FLASHMAN_CLIENT_SECRET=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_CLIENT_SECRET || echo '^\$')
        CUSTOM_FLASHMAN_CLIENT_SECRET=\"CONFIG_FLASHMAN_CLIENT_SECRET=\\\"${params.AUTHCLIENTSECRET}\\\"\"
        sed -i -e '\\,'\$DEFAULT_FLASHMAN_CLIENT_SECRET',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_CLIENT_SECRET >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_MQTT_PORT=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_MQTT_PORT || echo '^\$')
        CUSTOM_MQTT_PORT=\"CONFIG_MQTT_PORT=\\\"${params.MQTTPORT}\\\"\"
        sed -i -e '\\,'\$DEFAULT_MQTT_PORT',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_MQTT_PORT >> ${env.WORKSPACE}/\$REPO/.config
        
        DEFAULT_FLASHMAN_USE_AUTH_SERVER=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_FLASHMAN_USE_AUTH_SERVER || echo '^\$')

        if [ \"${params.AUTHENABLESERVER}\" = \"true\" ]
        then
          CUSTOM_FLASHMAN_USE_AUTH_SERVER=\"CONFIG_FLASHMAN_USE_AUTH_SERVER=y\"
        else
          CUSTOM_FLASHMAN_USE_AUTH_SERVER=\"# CONFIG_FLASHMAN_USE_AUTH_SERVER is not set\"
        fi

        sed -i -e '\\,'\$DEFAULT_FLASHMAN_USE_AUTH_SERVER',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_FLASHMAN_USE_AUTH_SERVER >> ${env.WORKSPACE}/\$REPO/.config
        

        DEFAULT_ZABBIX_SERVER_ADDR=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_ZABBIX_SERVER_ADDR)
        CUSTOM_ZABBIX_SERVER_ADDR=\"CONFIG_ZABBIX_SERVER_ADDR=\\\"${params.ZABBIXSERVERADDR}\\\"\"
        sed -i -e '\\,'\$DEFAULT_ZABBIX_SERVER_ADDR',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_ZABBIX_SERVER_ADDR >> ${env.WORKSPACE}/\$REPO/.config

        DEFAULT_ZABBIX_SEND_DATA=\$(cat ${env.WORKSPACE}/\$REPO/.config | grep CONFIG_ZABBIX_SEND_DATA || echo '^\$')

        if [ \"${params.ZABBIXSENDNETDATA}\" = \"true\" ]
        then
          CUSTOM_ZABBIX_SEND_DATA=\"CONFIG_ZABBIX_SEND_DATA=y\"
        else
          CUSTOM_ZABBIX_SEND_DATA=\"# CONFIG_ZABBIX_SEND_DATA is not set\"
        fi

        sed -i -e '\\,'\$DEFAULT_ZABBIX_SEND_DATA',d' ${env.WORKSPACE}/\$REPO/.config
        echo \$CUSTOM_ZABBIX_SEND_DATA >> ${env.WORKSPACE}/\$REPO/.config

        
        ##
        ## End of replace variables section
        ##

        make defconfig

        echo ${params.FLASHMANPUBKEY} > ${env.WORKSPACE}/\$REPO/id_rsa_flashman.pub

        ##
        ## Add failsafe password using shared secret
        ##

        DEFAULT_FAILSAFE_PASSWD=\$(cat ${env.WORKSPACE}/\$REPO/package/base-files/files/etc/shadow | grep root)
        CUSTOM_FAILSAFE_PASSWD=\$(openssl passwd -1 -salt \$(openssl rand -base64 6) ${params.AUTHCLIENTSECRET})
        sed -i -e '\\,'\$DEFAULT_FAILSAFE_PASSWD',d' ${env.WORKSPACE}/\$REPO/package/base-files/files/etc/shadow
        echo \"root:\"\$CUSTOM_FAILSAFE_PASSWD\":0:0:99999:7:::\" >> ${env.WORKSPACE}/\$REPO/package/base-files/files/etc/shadow

        ##
        ## End failsafe password using shared secret
        ##

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

      sh """
        DIFFCONFIG=\$(ls ${env.WORKSPACE}/diffconfigs | grep ${params.TARGETMODEL} | head -1)
        REPO=\$(echo \$DIFFCONFIG | awk -F '~' '{print \$1}')

        ##
        ## Factory image
        ##

        OUTPUTIMGMODEL=\$(echo ${params.OUTPUTIMGMODEL} | awk '{print tolower(\$0)}')
        if [ \"\$REPO\" = \"openwrt\" ]
        then
            OUTPUTIMGMODELVER=\$(echo ${params.TARGETMODEL} | awk -F '-' '{print \$NF}' | awk '{print tolower(\$0)}')
        else
            OUTPUTIMGMODELVER=\$(echo ${params.OUTPUTIMGMODELVER} | awk '{print tolower(\$0)}')
        fi

        TARGETIMG=\$(find ${env.WORKSPACE}/\$REPO/bin -name '*tftp-recovery.bin' | grep \$OUTPUTIMGMODEL-\$OUTPUTIMGMODELVER || echo '')
        if [ \"\$TARGETIMG\" = \"\" ]
        then
            TARGETIMG=\$(find ${env.WORKSPACE}/\$REPO/bin -name '*factory-br.bin' | grep \$OUTPUTIMGMODEL-\$OUTPUTIMGMODELVER || echo '')
        fi
        if [ \"\$TARGETIMG\" = \"\" ]
        then
            TARGETIMG=\$(find ${env.WORKSPACE}/\$REPO/bin -name '*factory.bin' | grep \$OUTPUTIMGMODEL-\$OUTPUTIMGMODELVER)
        fi        

        OUTPUTIMGVENDOR=\$(echo ${params.OUTPUTIMGVENDOR} | awk '{print toupper(\$0)}')
        OUTPUTIMGMODEL=\$(echo ${params.OUTPUTIMGMODEL} | awk '{print toupper(\$0)}')
        OUTPUTIMGMODELVER=\$(echo ${params.OUTPUTIMGMODELVER} | awk '{print toupper(\$0)}')
        IMGPRENAME=\$OUTPUTIMGVENDOR'_'\$OUTPUTIMGMODEL'_'\$OUTPUTIMGMODELVER'_'${params.FLASHMANRELEASEID}'_FACTORY'
        IMGNAME=\$IMGPRENAME'.bin'
        IMGZIP=\$IMGPRENAME'.zip'

        if [ -f \$IMGZIP ]
        then
            rm \$IMGZIP
        fi
 
        cp \$TARGETIMG \$IMGNAME

        ##
        ## Verify image integrity against data
        ##

        binwalk -e \$IMGNAME
        SQUASHCONFIG='_'\$IMGNAME'.extracted/squashfs-root/usr/share/flashman_init.conf'

        IMG_FLM_SSID_SUFFIX=\$(cat \$SQUASHCONFIG | grep 'FLM_SSID_SUFFIX=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"${params.FLASHMANSSIDSUFFIX}\" = \"none\" ]
        then
          if [ \"\$IMG_FLM_SSID_SUFFIX\" != \"none\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        else
          if [ \"\$IMG_FLM_SSID_SUFFIX\" != \"lastmac\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        fi

        IMG_FLM_SSID=\$(cat \$SQUASHCONFIG | grep 'FLM_SSID=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_SSID\" != \"${params.FLASHMANSSIDPREFIX}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_PASSWD=\$(cat \$SQUASHCONFIG | grep 'FLM_PASSWD=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_PASSWD\" != \'${params.FLASHMANWIFIPASS}\' ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_24_CHANNEL=\$(cat \$SQUASHCONFIG | grep 'FLM_24_CHANNEL=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_24_CHANNEL\" != \"${params.FLASHMANWIFICHANNEL}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_RELID=\$(cat \$SQUASHCONFIG | grep 'FLM_RELID=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_RELID\" != \"${params.FLASHMANRELEASEID}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_SVADDR=\$(cat \$SQUASHCONFIG | grep 'FLM_SVADDR=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_SVADDR\" != \"${params.FLASHMANSERVERADDR}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_NTP_SVADDR=\$(cat \$SQUASHCONFIG | grep 'NTP_SVADDR=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_NTP_SVADDR\" != \"${params.FLASHMANNTPADDR}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_WAN_PROTO=\$(cat \$SQUASHCONFIG | grep 'FLM_WAN_PROTO=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_WAN_PROTO\" != \"${params.FLASHMANWANPROTO}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_WAN_MTU=\$(cat \$SQUASHCONFIG | grep 'FLM_WAN_MTU=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_WAN_MTU\" != \"${params.FLASHMANWANMTU}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_MQTT_PORT=\$(cat \$SQUASHCONFIG | grep 'MQTT_PORT=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_MQTT_PORT\" != \"${params.MQTTPORT}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_CLIENT_ORG=\$(cat \$SQUASHCONFIG | grep 'FLM_CLIENT_ORG=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"\$IMG_FLM_CLIENT_ORG\" != \"${params.FLASHMANCLIENTORG}\" ]
        then
          echo 'Generated image parameter does not match'
          rm -rf '_'\$IMGNAME'.extracted'
          exit 1
        fi
        IMG_FLM_USE_AUTH_SVADDR=\$(cat \$SQUASHCONFIG | grep 'FLM_USE_AUTH_SVADDR=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"${params.AUTHENABLESERVER}\" = \"true\" ]
        then
          if [ \"\$IMG_FLM_USE_AUTH_SVADDR\" != \"y\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
          IMG_FLM_AUTH_SVADDR=\$(cat \$SQUASHCONFIG | grep 'FLM_AUTH_SVADDR=' | awk -F= '{print \$2}' | sed 's,\",,g')
          if [ \"\$IMG_FLM_AUTH_SVADDR\" != \"${params.AUTHSERVERADDR}\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
          IMG_FLM_CLIENT_SECRET=\$(cat \$SQUASHCONFIG | grep 'FLM_CLIENT_SECRET=' | awk -F= '{print \$2}' | sed 's,\",,g')
          if [ \"\$IMG_FLM_CLIENT_SECRET\" != \"${params.AUTHCLIENTSECRET}\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        else
          if [ \"\$IMG_FLM_USE_AUTH_SVADDR\" != \"\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        fi
        IMG_ZBX_SEND_DATA=\$(cat \$SQUASHCONFIG | grep 'ZBX_SEND_DATA=' | awk -F= '{print \$2}' | sed 's,\",,g')
        if [ \"${params.ZABBIXSENDNETDATA}\" = \"true\" ]
        then
          if [ \"\$IMG_ZBX_SEND_DATA\" != \"y\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
          IMG_ZBX_SVADDR=\$(cat \$SQUASHCONFIG | grep 'ZBX_SVADDR=' | awk -F= '{print \$2}' | sed 's,\",,g')
          if [ \"\$IMG_ZBX_SVADDR\" != \"${params.ZABBIXSERVERADDR}\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        else
          if [ \"\$IMG_ZBX_SEND_DATA\" != \"\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        fi
        if [ \"${params.FLASHMANWANPROTO}\" = \"pppoe\" ]
        then
          IMG_FLM_WAN_PPPOE_USER=\$(cat \$SQUASHCONFIG | grep 'FLM_WAN_PPPOE_USER=' | awk -F= '{print \$2}' | sed 's,\",,g')
          if [ \"\$IMG_FLM_WAN_PPPOE_USER\" != \"${params.FLASHMANPPPOEUSER}\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
          IMG_FLM_WAN_PPPOE_PASSWD=\$(cat \$SQUASHCONFIG | grep 'FLM_WAN_PPPOE_PASSWD=' | awk -F= '{print \$2}' | sed 's,\",,g')
          if [ \"\$IMG_FLM_WAN_PPPOE_PASSWD\" != \"${params.FLASHMANPPPOEPASS}\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
          IMG_FLM_WAN_PPPOE_SERVICE=\$(cat \$SQUASHCONFIG | grep 'FLM_WAN_PPPOE_SERVICE=' | awk -F= '{print \$2}' | sed 's,\",,g')
          if [ \"\$IMG_FLM_WAN_PPPOE_SERVICE\" != \"${params.FLASHMANPPPOESERVICE}\" ]
          then
            echo 'Generated image parameter does not match'
            rm -rf '_'\$IMGNAME'.extracted'
            exit 1
          fi
        fi

        rm -rf '_'\$IMGNAME'.extracted'

        ##
        ## End of image integrity verification section
        ##

        zip \$IMGZIP \$IMGNAME

        curl -u ${params.ARTIFACTORYUSER}:${params.ARTIFACTORYPASS} \\
        -X PUT \"https://artifactory.anlix.io/artifactory/firmwares/${params.FLASHMANCLIENTORG}/\"\$IMGZIP \\
        -T \$IMGZIP

        ##
        ## Sysupgrade image
        ##

        OUTPUTIMGMODEL=\$(echo ${params.OUTPUTIMGMODEL} | awk '{print tolower(\$0)}')
        if [ \"\$REPO\" = \"openwrt\" ]
        then
            OUTPUTIMGMODELVER=\$(echo ${params.TARGETMODEL} | awk -F '-' '{print \$NF}' | awk '{print tolower(\$0)}')
        else
            OUTPUTIMGMODELVER=\$(echo ${params.OUTPUTIMGMODELVER} | awk '{print tolower(\$0)}')
        fi
        TARGETIMG=\$(find ${env.WORKSPACE}/\$REPO/bin -name '*sysupgrade.bin' | grep \$OUTPUTIMGMODEL-\$OUTPUTIMGMODELVER)

        OUTPUTIMGVENDOR=\$(echo ${params.OUTPUTIMGVENDOR} | awk '{print toupper(\$0)}')
        OUTPUTIMGMODEL=\$(echo ${params.OUTPUTIMGMODEL} | awk '{print toupper(\$0)}')
        OUTPUTIMGMODELVER=\$(echo ${params.OUTPUTIMGMODELVER} | awk '{print toupper(\$0)}')
        IMGPRENAME=\$OUTPUTIMGVENDOR'_'\$OUTPUTIMGMODEL'_'\$OUTPUTIMGMODELVER'_'${params.FLASHMANRELEASEID}
        IMGNAME=\$IMGPRENAME'.bin'
        IMGZIP=\$IMGPRENAME'.zip'

        if [ -f \$IMGZIP ]
        then
            rm \$IMGZIP
        fi
 
        cp \$TARGETIMG \$IMGNAME
        zip \$IMGZIP \$IMGNAME

        curl -u ${params.ARTIFACTORYUSER}:${params.ARTIFACTORYPASS} \\
        -X PUT \"https://artifactory.anlix.io/artifactory/upgrades/${params.FLASHMANCLIENTORG}/\"\$IMGZIP \\
        -T \$IMGZIP
      """
    }
}
