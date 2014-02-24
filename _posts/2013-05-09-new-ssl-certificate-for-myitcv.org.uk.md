---
date: 2013-05-09
layout: post
title: New SSL certificate for myitcv.org.uk
location: London
author: paul
---

Visitors to [myitcv.org.uk](http://myitcv.org.uk) might have noticed that the SSL certificate for the domain has changed
recently.

For most modern operating systems (and browsers) this should not present a problem. But for those with older systems,
particularly systems that have not been patched/updated fully (a particular example that came up the other day was an
old Windows XP machine that appeared to be missing any sort of update to its root certificates), you might receive
warnings in your browser that the "identity of the site cannot be verified."

If you are experiencing problems, you simply need to download and install the following GoDaddy SSL certificates:

* [Go Daddy Class 2 Certification Authority Root
Certificate](https://certs.godaddy.com/anonymous/repository.pki?streamfilename=gd-class2-root.crt&actionMethod=anonymous%2Frepository.xhtml%3Arepository.streamFile%28%27%27%29&cid=2438891)
* [Go Daddy Class 2 Certification Authority Root Certificate -
G2](https://certs.godaddy.com/anonymous/repository.pki?streamfilename=gdroot-g2.crt&actionMethod=anonymous%2Frepository.xhtml%3Arepository.streamFile%28%27%27%29&cid=2438891)

And then upgrade your operating system!