#!/bin/bash
swayidle -w \
	timeout 240 'swaylock' \
	timeout 480 'systemctl suspend'
