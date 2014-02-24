---
date: 2013-06-12
layout: post
title: VirtualBox Ubuntu guest DNS lookups failing after Mac host wake from sleep
location: London
author: paul
tags:
- mac
- virtualbox
---

I run [Ubuntu Linux](http://www.ubuntu.com/) as a guest operating system within
[VirtualBox](https://www.virtualbox.org/wiki/Downloads) on my [MacBook Pro](http://www.apple.com/uk/macbook-pro/)

Often (and for some reason more often than not lately) when I open my Mac to wake it from sleeping, Ubuntu has lost the
ability to do a DNS lookup. `ping` to any IP address works, but DNS is entirely broken.

[This problem was reported](https://www.virtualbox.org/ticket/10864) in Oct 2012 and reported as being fixed in version
`>= 4.1` of VirtualBox. At the time of writing I am running `4.2.12` and yet still see the problem. The solution for now
appears to be to run the following command from the host (as the previously linked bug report suggests):

```bash
VBoxManage modifyvm VMNAME --natdnshostresolver1 on
```

