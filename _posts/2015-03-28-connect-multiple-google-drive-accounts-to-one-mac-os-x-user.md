---
date: 2015-03-28
layout: post
title: Connect multiple Google Drive accounts to one Mac OS X user
location: London
author: paul
---

Installed on your Mac/PC, [Google Drive](https://support.google.com/drive/?hl=en#topic=6069785) allows you to sync
files/folders (to use the terminology from the support page) with Google Drive on the web. That is to say for example,
a Mac OS X user can connect his/her Google Drive account so that files/folders stored locally on the OS hard drive are
automatically synced with the contents of Google Drive on the web.

Whilst it is possible to be [signed into multiple Google accounts at once in a
browser](https://support.google.com/accounts/answer/1721977?hl=en), with Google Drive on your Mac/PC it is [only
possible to be signed into one account at a time](https://support.google.com/drive/answer/2405894?hl=en), i.e. you can
only sync one account's files/folders at any given time. This is something of a restriction for those of us who have
multiple accounts for genuine reasons, e.g. multiple work accounts and a personal account, where sharing across domains is either
not possible/desirable, and where sync access to files from the same machine _is_ desirable.

There are [various](http://techno-dribble.blogspot.hk/2015/03/macos-using-multiple-google-drive.html)
[solutions](http://truongtx.me/2013/06/30/macos-using-multiple-google-drive-accounts-at-the-same-time/) elsewhere on the
web that variously talk about opening up permissions etc. but I could never truly get these to work (and to be honest the
thought of `chmod 777` on anything made me physically sick). Hence the alternative that I have laid out below.

### WARNING

The following instructions have not be heavily road-tested, so please follow with caution. Use at your own
risk, etc.

Let us assume:

* We are using Yosemite (only tested under Yosemite, may well work under other versions of OS X)
* The Mac OS X user who wants to connect and sync two Google Drive accounts is `user_1`
* `user_1` has access to both `user_1@gmail.com` (personal account) and `user_1@work.com` (Google Apps work account)
* `user_1` has followed the standard Google Drive setup to connect and sync `user_1@gmail.com` to `"/Users/user_1/Google Drive"`
* `user_1` wants to be able to connect and sync `user_1@work.com` to `"/Users/user_1/Google Drive - work"`

### Steps

Let's assume you are already logged in as `user_1`

0. Install [FUSE for OS X](https://osxfuse.github.io/)
1. Install [Brew](http://brew.sh/)
2. In a Terminal: `brew install bindfs`
3. Create a new Mac OS X user called `user_2`
4. Login as this user (it is fastest to [switch user](https://support.apple.com/kb/PH18897?locale=en_US) from `user_1`)
5. In a Terminal: `mkdir "$HOME/Google Drive" && chmod 700 $_`
5. Setup Google Drive as the user `user_2` to connect `user_1@work.com`, syncing to `/Users/user_2/Google Drive` (the default)
6. Let this sync complete
7. Switch user back to `user_1`
8. In a Terminal: `mkdir "/Users/user_1/Google Drive - work"`
9. In a Terminal: `sudo bindfs -o local --mirror=user_2,user_1,@staff --create-for-user=user_2 "/Users/user_2/Google Drive" "/Users/user_1/Google Drive - work"`

_With thanks to [this link](http://apple.stackexchange.com/questions/114761/how-can-i-fix-the-spotlight-index-for-an-encfs-mounted-directory) for the
`-o local fix`_

Done. This should now allow you to read/write/etc. files in `"/Users/user_1/Google Drive - work"` as `user_1`.
These changes will get written as if you were `user_2`, which allows the Google Drive sync for `user_2` (linked to `user_1@work.com`)
to proceed as if the changes had been made by the `user_2` Mac OS X user.

### Conclusion

This approach appears to work and doesn't interfere with the normal operation of Google Drive for Mac OS X
(it just thinks it's running for another user). However, this has not been heavily load/road tested.

The one thing that doesn't work is Spotlight indexing of the second Google Drive sync. You will notice above that we
`chmod 700 "/Users/user_2/Google Drive"`. This is important because otherwise `user_1` may see the Spotlight search
results from that directory (by default this shouldn't be the case, but we `chmod 700` to be sure),
as opposed to the FUSE mount at `"/Users/user_1/Google Drive - work"`. Unfortunately I
haven't found a way to make Spotlight index the FUSE mount for `user_1` (comments/thoughts welcomed).

One thing you will need to remember, if you restart your computer you need to:

1. Switch user to `user_2` to ensure Google Drive is running (should start by default on login)
2. Perform the `sudo bindfs ...` step above once you have logged in as `user_1`, else  `"/Users/user_1/Google Drive - work"` will be empty

Comments/thoughts on this approach welcomed below.
