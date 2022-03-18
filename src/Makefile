include $(TOPDIR)/rules.mk

CC = gcc
OBJS = paho/MQTTConnectClient.o paho/MQTTSerializePublish.o paho/MQTTPacket.o paho/MQTTSubscribeClient.o paho/MQTTDeserializePublish.o paho/MQTTConnectServer.o paho/MQTTSubscribeServer.o paho/MQTTUnsubscribeServer.o paho/MQTTUnsubscribeClient.o
OBJS-FLASH-UTILS = flash-utils/flash-utils.o

all:

# Only add anlix-flash-utils if W5
ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_W51200F), y)
all: anlix-mqtt pk anlix-flash-utils
else
all: anlix-mqtt pk
endif

%.o: %.c
	$(CC) $(CFLAGS) -Ipaho -c -o $@ $<

anlix-mqtt: $(OBJS) MQTTClient.o anlix-mqtt-transport.o anlix-mqtt.o
	$(CC) $(LDFLAGS) -o $@ $(OBJS) MQTTClient.o anlix-mqtt-transport.o anlix-mqtt.o -lmbedtls -lmbedx509 -lmbedcrypto

pk: pk.o
	$(CC) $(LDFLAGS) -o $@ pk.o -lmbedtls -lmbedx509 -lmbedcrypto

anlix-flash-utils: $(OBJS-FLASH-UTILS)
	$(CC) $(LDFLAGS) -Werror -o $@ $(OBJS-FLASH-UTILS)

clean:
	rm *.o paho/*.o flash-utils/*.o anlix-mqtt pk anlix-flash-utils
