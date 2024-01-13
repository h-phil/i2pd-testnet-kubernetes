#!/bin/bash
set -xe
sleep 1

# router.config
if [ -f "/tmp/router-config/router.config" ]; then
	echo "router.config file was provided via configmap"
	if [ ! -f "/i2p/.i2p/router.config" ]; then
		cp /tmp/router-config/router.config /i2p/.i2p/router.config
	fi
else
	echo "router.config was not provided via configmap. skipping..."
fi

# logger.config
if [ -f "/tmp/logger-config/logger.config" ]; then
	echo "logger.config file was provided via configmap"
	if [ ! -f "/i2p/.i2p/logger.config" ]; then
		cp /tmp/logger-config/logger.config /i2p/.i2p/logger.config
	fi
else
	echo "logger.config was not provided via configmap. skipping..."
fi

# clients.config.d
if [ -d "/tmp/clients.config.d" ]; then
	echo "clients.config.d was provided via configmap"
	mkdir -p /i2p/.i2p/clients.config.d
	for f in "/tmp/clients.config.d/*"; do
		cp $f /i2p/.i2p/clients.config.d/
	done
else
	echo "clients.config.d was not provided via configmap. skipping ..."
fi

# hacky
mkdir -p /i2p/.i2p/logs
ln -sf /dev/stdout /i2p/.i2p/logs/stdout
