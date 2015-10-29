---
date: 2015-10-03
layout: post
title: Auto-(re) connect to a VPN in Mac OS X
location: London
author: paul
---

Here's a simple bash script that ensures you remain connected to an existing VPN connection as long as your computer is
connected to the internet:

```bash
#!/bin/bash

# set these variables
VPN_IP=A.A.A.A
INTERNET_TEST_IP=B.B.B.B
VPN_CONNECTION="myVPNConnection"

while true
do
  ping -n -t 1 -c 2 $VPN_IP > /dev/null 2>&1
  if [ "$?" != "0"  ]
  then
    ping -n -t 1 -c 1 $INTERNET_TEST_IP > /dev/null 2>&1
    if [ "$?" == "0"  ]
    then
      scutil --nc start "$VPN_CONNECTION"
    fi
  fi
  sleep 1
done
```

To use this:

* Create a directory in your home directory called `bin`
* Copy the script above into a new file, `$HOME/bin/keepVPNConnected`
* Set `VPN_IP`, `INTERNET_TEST_IP` and `VPN_CONNECTION` as indicated. `VPN_IP` should be set to an IP address behind the
  VPN that responds to `ping` requests
* `chmod +x $HOME/bin/keepVPNConnected`
* Add `keepVPNConnected` to your [login items](https://support.apple.com/kb/PH21985?locale=en_US&viewlocale=en_US) - I
  also select the 'Hide' option

You can obviously run this manually from the terminal
