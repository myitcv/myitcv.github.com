---
date: 2013-06-01
layout: post
title: Showing/listing the files Google Drive is actively syncing
location: London
author: paul
tags:
- mac
- google drive
---

It's a bit of a annoyance that Google Drive (for Mac at least) doesn't give you any way of seeing which files it is
trying to sync. Or for that matter a percentage progress indicator (or similar). This is particularly a problem when it
comes to large files.

I finally broke the other day and quickly rustled up a command to solve the first problem:

```bash
ps x | grep 'Applications/Google Drive.app' | grep -v 'grep Applications' | awk '{print $1}' | xargs lsof -p | grep REG | grep "$HOME/Google Drive"
```

There are some assumptions to using this:

* You are using a Mac
* You have a standard Google Drive installation (is there any other sort?)
* You are syncing all files, and they are being synced to the directory `$HOME/Google Drive` - amend the script as necessary

This command will then generate a number of lines of output:

```bash
$ ps x | grep 'Applications/Google Drive.app' | grep -v 'grep Applications' | awk '{print $1}' | xargs lsof -p | grep REG | grep "$HOME/Google Drive"
Google    1073 pauljolly   58r     REG                1,4  24929489 4839584 /Users/pauljolly/Google Drive/file_1
Google    1073 pauljolly   61r     REG                1,4  33799201 4839578 /Users/pauljolly/Google Drive/file_2
Google    1073 pauljolly   62r     REG                1,4  22868396 4839590 /Users/pauljolly/Google Drive/file_3
```

I think the three lines here correspond to the fact that Google Drive syncs up to three files in parallel.

This can easily be wrapped in a script in case you need to run it regularly.
