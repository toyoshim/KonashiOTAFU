# KonashiOTAFU
Konashi OTA Firmware Upgrade Tool for OS X

![Screenshot](https://raw.githubusercontent.com/toyoshim/KonashiOTAFU/master/screenshot.png)

## About [Konashi](http://konashi.ux-xu.com/en/) and [Koshian](http://www.m-pression.com/solutions/boards/koshian)
Koshian is a Broadcom's BCM20737 based BLE module for hobby use.
It isn't expensive so much (< $10), and is distributed with a interesting firmware, Konashi.
Konashi allows us to control the BLE device through JavaScript running on a custom WebView/iOS.
Since the device is open, we can easily control it by our own way, e.g., using Web Bluetooth, etc.

## Over-the-Air Firmware Upgrade
Konashi's firmware provides an Over-the-Air Firmware Upgrade service with which you can
upgrade the firmware via Bluetooth, but any tool to use the OTAFU service isn't provided officially yet.
Unfortunatelly, the protocol is slightly different from the original Broadcom's OTAFU service,
and there are some bugs that makes it difficult to reuse the Broadcom's OTAFU tools.

Yep, KonashiOTAFU is an unofficial OTAFU tool to download your firmware to the BCM20737 chip on your Koshian.

## Notices
Please use this software at your own risk. If you download a firmware that does not provide any OTAFU service,
you will need to download another firmware via wired debug UART ports.

This tool may work even for the firmwares that support Broadcom's OTAFU. But, there is no garantee.
