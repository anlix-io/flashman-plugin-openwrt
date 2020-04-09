CC = gcc
OBJS = paho/MQTTConnectClient.o paho/MQTTSerializePublish.o paho/MQTTPacket.o paho/MQTTSubscribeClient.o paho/MQTTDeserializePublish.o paho/MQTTConnectServer.o paho/MQTTSubscribeServer.o paho/MQTTUnsubscribeServer.o paho/MQTTUnsubscribeClient.o

all: anlix-mqtt pk_sign pk_verify

%.o: %.c
	$(CC) $(CFLAGS) -Ipaho -c -o $@ $<

anlix-mqtt: $(OBJS) MQTTClient.o anlix-mqtt-transport.o anlix-mqtt.o
	$(CC) $(LDFLAGS) -o $@ $(OBJS) MQTTClient.o anlix-mqtt-transport.o anlix-mqtt.o -lmbedtls -lmbedx509 -lmbedcrypto

pk_sign: pk_sign.o
	$(CC) $(LDFLAGS) -o $@ pk_sign.o -lmbedtls -lmbedx509 -lmbedcrypto

pk_verify: pk_verify.o
	$(CC) $(LDFLAGS) -o $@ pk_verify.o -lmbedtls -lmbedx509 -lmbedcrypto

clean:
	rm *.o paho/*.o anlix-mqtt pk_sign pk_verify
