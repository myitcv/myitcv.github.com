---
date: 2015-03-28
layout: post
title: Connect multiple Google Drive accounts to one Mac OS X user
location: London
author: paul
---

**Update 2017-10-16:** major update to article following the release of Backup and Sync; no longer require `bindfs`<br/>

[Google Drive](https://www.google.co.uk/drive/download/) allows you to sync files/folders (to use the terminology from
the support page) on your Mac/PC with Google Drive on the web. That is to say for example, a Mac OS X user can connect
their Google Drive account such that files/folders stored locally on the OS hard drive are automatically synced with the
contents of Google Drive on the web.

As of September/October 2017, Google released two replacements for the old Google Drive application: [Backup and
Sync](https://www.google.co.uk/drive/download/backup-and-sync/) (aimed at personal accounts) and [Drive File
Stream](https://support.google.com/a/answer/7491144?utm_medium=et&utm_source=aboutdrive&utm_content=getstarted&utm_campaign=en_us)
(aimed at business customers who have G Suite accounts). It turns out that, despite the apparent distinction, Backup and
Sync can also be used for "business" accounts (i.e. users of G Suite accounts). Drive File Stream can only be used by G
Suite users, and presents a virtual file system that syncs files on demand.

This article focuses on the use of **Backup and Sync** for either personal or business (G Suite) accounts.

Whilst it is possible to be [signed in to multiple Google accounts at once in a
browser](https://support.google.com/accounts/answer/1721977?hl=en), with Backup and Sync on your Mac/PC it is only
possible to be signed in to one account at a time, i.e. you can only sync one account's files/folders at any given time.
This is something of a restriction for those of us who have multiple accounts for genuine reasons, e.g. multiple work
accounts and a personal account, where sharing across domains is either not possible/desirable, and where sync access to
files from the same machine _is_ desirable.

There are [various](http://techno-dribble.blogspot.hk/2015/03/macos-using-multiple-google-drive.html)
[solutions](http://truongtx.me/2013/06/30/macos-using-multiple-google-drive-accounts-at-the-same-time/) elsewhere on the
web that variously talk about opening up permissions etc. but I could never truly get these to work (and to be honest the
thought of `chmod 777` on anything made me rather ill). Hence the alternative that I have laid out below. _With thanks to
**`@Moose`** for a great contribution in the comments._

### WARNING

The following instructions have not be heavily road-tested, so please follow with caution. Use at your own
risk, etc.

Let us assume:

* We are using High Sierra (only tested under High Sierra, may well work under other versions of OS X)
* Tested using Backup and Sync `v3.36.6721.3394`
* The Mac OS X user who wants to connect and sync two Google Drive accounts is `user_1`
* `user_1` has access to both `user_1@gmail.com` (personal account) and `user_1@work.com` (G Suite work account - could
  equally be another personal account)
* `user_1` has followed the standard Backup and Sync setup to connect and sync `user_1@gmail.com` to `"/Users/user_1/Google Drive"`
* `user_1` wants to be able to connect and sync `user_1@work.com` to `"/Users/user_1/Google Drive - work"`
* You have configured your system so that `user_1` can [run `sudo` commands](https://support.apple.com/en-gb/HT202035)

### Steps

Let's assume you are already logged in as `user_1` (lines in `code blocks` should be run in the Terminal):

1. Create a new Mac OS X user called `user_2`
2. [Switch user](https://support.apple.com/kb/PH18897?locale=en_US) (do not logout) to `user_2`
3. In a Terminal: `mkdir "$HOME/Google Drive" && chmod 700 "$HOME/Google Drive"`
3. Setup Backup and Sync as the user `user_2` to connect `user_1@work.com`, syncing to `/Users/user_2/Google Drive` (the default)
4. Let this sync complete
5. Switch user back to `user_1` (again, do not logout)
6. `sudo chown root:user_2 /Users/user_2/Google\ Drive`
7. `sudo chmod 770 /Users/user_2/Google\ Drive`
8. `sudo chmod -R +a "user:user_1 allow list,add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,writesecurity,chown,file_inherit,directory_inherit,delete" /Users/user_2/Google\ Drive/`
9. `sudo chmod -R +a "user:user_2 allow list,add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,writesecurity,chown,file_inherit,directory_inherit,delete" /Users/user_2/Google\ Drive/`
10. `ln -s /Users/user_2/Google\ Drive/ /Users/user_1/Google\ Drive\ -\ work`

Done. This should now allow you to read/write/etc. files in `"/Users/user_1/Google Drive - work"` as `user_1`.  These
changes will get written as if you were `user_2`, which allows the Backup and Sync sync process for `user_2` (linked to
`user_1@work.com`) to proceed as if the changes had been made by the `user_2` Mac OS X user.

### Conclusion

This approach appears to work and doesn't interfere with the normal operation of Backup and Sync for Mac OS X (it just
thinks it's running for another user). However, this has not been heavily load/road tested.

As of this latest update (2017-10-16) even Spotlight works for `user_1` for the files synced via `user_2`.

One thing you will need to remember, if you restart your computer you need to: switch user to `user_2` to ensure Backup
and Sync is started (should start by default on login).

Comments/thoughts on this approach welcomed below.

<hr/>
&nbsp;

_Older revision history_

**Update 2015-09-25:** clarify the term 'switch user' and emphasise that logout/login is not equivalent<br/>
**Update 2015-04-18:** updated `bindfs` command to use `--xattr-none` to avoid extended attribute problems when creating
files using Finder<br/>
**Update 2015-06-09:** updated `bindfs` command to use `-o volname="XYZ"` to set a custom name for the mount (as opposed
to the ugly default). With thanks to Dennis Jarvis for highlighting this<br/>
