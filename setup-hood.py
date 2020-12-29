#!/usr/bin/env python3
# specs:
# - take hood id as argument
# - download and validate hood file
# - generate hostapd configuration
# - generate fastd configuration
#
# interfaces:
#  fastd interface      fastd-$hoodid  
#  batman interface     bat-$hoodid
#  bridge interface     br-$hoodid
#
# files:
# - /etc/fff-ap/fastd-$hoodid.conf
# - /etc/fff-ap/hostapd-$hoodid.conf

import urllib.request
import json
import sys

hoodid = sys.argv[1]

url = 'https://keyserver.freifunk-franken.de/v2/index.php?hoodid=' + hoodid
req = urllib.request.Request(url)

bridge='br-' + hoodid

conf_fastd = '/etc/fff-ap/fastd-' + hoodid + '.conf'
conf_hostapd = '/etc/fff-ap/hostapd-' + hoodid + '.conf'

r = urllib.request.urlopen(req).read()
cont = json.loads(r.decode('utf-8'))

if cont['version'] != 1:
  raise Exception('hoodfile version is ' + str(cont['version']) + ', expected 1')

with open(conf_hostapd, 'w') as f:
  channel = max(1, min(11, int(cont['hood']['channel2'])))
  f.write('interface=wlan0\n')
  f.write('bridge=' + bridge + '\n')
  f.write('driver=nl80211\n')
  f.write('ssid=' + cont['hood']['essid'] + '\n')
  f.write('channel=' + str(channel) + '\n')
  f.write('hw_mode=g\n')
  f.write('macaddr_acl=0\n')
  f.write('auth_algs=3\n')
  f.write('ignore_broadcast_ssid=0\n')
  f.write('wpa=0\n')
  
with open(conf_fastd, 'w') as f:
  f.write('log level error;\n')
  f.write('log to syslog as "fastd-' + hoodid + '" level warn;\n')
  f.write('interface "fastd-' + hoodid + '";\n')
  f.write('method "null";\n')
  f.write('bind any;\n')
  f.write('secret "e033835f93eb903bcb4b876583894742efbdc70e9616b307ced626919993486a";\n')
  f.write('mtu 1426;\n')
  f.write('secure handshakes no;\n')
  for peer in cont['vpn']:
    f.write('peer "' + peer['name'] + '" {\n')
    f.write('  remote "' + peer['address'] + '" port ' + str(peer['port']) + ';\n')
    f.write('  key "' + peer['key'] + '";\n')
    f.write('}\n')



