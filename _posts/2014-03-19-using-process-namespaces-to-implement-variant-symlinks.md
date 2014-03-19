---
date: 2014-03-18
layout: post
title: Using process namespaces to implement variant symlinks
location: London
author: paul
---

*See [change history](#changehistory) for a list of changes to this article*

This article covers my attempts to implement behaviour akin to variant symlinks within my development environment. It
charts a failed attempt at building a fuse-based file system solution through to a working (but somewhat hacky) solution
that uses Linux process namespaces. It then presents an example of how this approach can be used to emulate the
functionality provided my `gvm`.

## Motivation

Recently I looked at rewriting the `LISTEN/NOTIFY` module of [`github.com/lib/pq`](https://github.com/lib/pq) to move
away from a lock-based implementation to one that uses channels.  The package itself and the detail of my proposed
rewrite are totally unimportant. But what is important was that my rewrite would require me to test the package under
multiple Go versions.

At the time of writing this article I am using [`gvm`] to manage those multiple Go versions and associated package sets.

But it struck me that here, in the form of `gvm`, was yet another version management tool for language XYZ. In the past
I have used [`rbenv`] for Ruby, [`nvm`] for Node... The list goes on. All do rather magic manipulation of environment,
shell functions etc. It's pretty messy. (_I should say I'm VERY grateful to the authors of these respective packages
for having gone to the trouble of writing this stuff in the first place_)

There must be a better way.

What if path names could be driven by (environment) variables such that `PATH`, `GOPATH` etc. could become dynamic?

```bash
$ export PATH=$HOME/gostuff/\$GO_VERSION/bin:$PATH
```

_(the backslash here being the way that Bash allows you to delay the evaluation of the variable that follows; useful for
example in the setting of `PS1`)_

This is how I first stumbled across variant symlinks...

## Variant symlinks - background

The idea behind [variant
symlinks](https://wiki.freebsd.org/200808DevSummit?action=AttachFile&do=get&target=variant-symlinks-for-freebsd.pdf) is
as follows (borrowing liberally from the example presented in the paper) - assume `bash` shell on Linux Ubuntu 13.10
throughout:

```bash
$ echo "contents of bar" > bar; echo "contents of baz" > baz
$ ln -s ’${XXX}’ foo
$ ls -l foo
lrwxr-xr-x 1 myitcv myitcv ... foo -> ${XXX}
$ XXX=bar cat foo
contents of bar
$ XXX=baz cat foo
contents of baz
```

The value of an environment variable drives the resolution of a symlink. In this case, the variable is `XXX`. A symbolic
link called `foo` points to the value of `XXX`. When a process executes, in this case `cat`, it assumes its environment
from the containing shell. In this case we have overridden the value of `XXX` in the call to `cat`. But the important
thing is that when `cat` executes a function that causes a file system access to a variant symlink file/directory, in
this case an [`open`](http://man7.org/linux/man-pages/man2/open.2.html) on `foo`, the value of `XXX` within `cat`'s
`/proc/PID/environ` is used to resolve the symlink.

## A fuse-based implementation in Go

Given this was very much a user-space problem I was trying to solve, I turned my attentions to [FUSE], specifically
[`go-fuse`]. My idea was write a FUSE file system that would serve as follows:

```
serve ->
  PathNodeFs ->
    VarSymFs ->
      LoopbackFileSystem
```

A [`PathNodeFs`](http://godoc.org/github.com/hanwen/go-fuse/fuse/pathfs#NewPathNodeFs) would resolve from inodes to
paths (FUSE works in terms of inodes); this would then delegate a call to `VarSymFs`, the bit I was writing. Using the
provided [`*fuse.Context`](http://godoc.org/github.com/hanwen/go-fuse/fuse#Context), `VarSymFs` would interrogate the
calling process' `/proc/PID/environ` for its environment variables, and resolve a full path. `VarSymFs` would then
delegate to a `LoopbackFileSystem` for all operations. `VarSymFs` was therefore going to be a rather dumb (and
expensive) pass-through

However, my attempt rather spectacularly hit the buffers for a number of reasons, principal among them that I couldn't
[`execve`](http://man7.org/linux/man-pages/man2/execve.2.html) any files within my mount. The reason? [A security
restriction imposed by the Linux kernl](https://lkml.org/lkml/2014/3/17/492). It's a fairly fundamental flaw if you can
execute anything on your file system. But the problem here was very much with my implementation, not the Linux kernel.

Indeed, had this hurdle been successfully crossed, performance with my implementation would undeniably have become an
issue.

You can see the fruits of my rather paltry efforts [on Github](https://github.com/myitcv/var-sym-fs).
Just bear in mind that it is a very rough cut... and doesn't work properly!

## Process namespaces to the rescue

My focus until this point had been on developing a solution around variant symlinks. However a [chance
comment](https://groups.google.com/d/msg/golang-nuts/WhI4Ok_51v0/RZfo5VDqNpMJ) in response a post requesting suggestions
from [the Go community](https://groups.google.com/forum/#!forum/golang-nuts) sent me in another direction entirely.

Aram's comment essentially refers to [the use of name spaces in Plan 9](http://plan9.bell-labs.com/sys/doc/names.html),
(a document that is well worth the read). But here I fell upon another fairly fundamental problem: I'm not using Plan 9.
Thankfully the Linux kernel [also has a namespace implementation](http://lwn.net/Articles/531114/) (I am unclear
on how exactly the two compare). The series of articles goes on to suggest [all manner of ways that process namespaces
can be used](http://www.ibm.com/developerworks/linux/library/l-mount-namespaces/index.html).

But my interest was fixed on one aspect of process namespaces in particular: [mount
namespaces](http://lwn.net/2001/0301/a/namespaces.php3).

> Mount namespaces (CLONE_NEWNS, Linux 2.4.19) isolate the set of filesystem mount points seen by a group of processes.
> Thus, processes in different mount namespaces can have different views of the filesystem hierarchy.

Whilst not driven by environment variables, process isolation can achieve exactly the same behaviour as variant
symlinks. Let's see how that works.

## Groundwork

<p style="color:red"><strong style="color:red">** WARNING **</strong> - this section (currently) involves making changes
to enable privileged functions and commands to be run by unprivileged users. Only continue if you know what you are
doing</p>

Everything that follows also assumes you have a [working Go installation](http://golang.org/doc/install) - all of these
commands have been tested against Go 1.2.1.

With the security caveat out the way, we first need to do some ground work to ensure an unprivileged user can:

1. start a process whose mount namespace is unshared (or detached) from its parent
2. perform a [`mount -n --bind`](http://linux.die.net/man/8/mount) under certain restricted scenarios

On Linux, anything to do with `mount` (and hence both points) requires root privilege. Indeed the `mount`
command itself is setuid to allow unprivileged users to list active mounts. And this is the bit that makes me
uncomfortable - in its current form (hence the term 'hacky') my solution involves relaxing those restrictions somewhat.

To help address these very real concerns, and to avoid making changes to 'system' installed/maintained
binaries/permissions, I have tried to adopt the principle of least privilege and written a couple of wrappers
to achieve the above two goals but only in *very specific circumstances*. Let's install those now:

```bash
$ go get -u github.com/myitcv/go-proc-ns/mount_wrap
# mount_wrap is automatically installed by the previous go get
$ go install github.com/myitcv/go-proc-ns/unshare_mounts
```

`unshare_mounts` runs a user's shell such that the shell is unshared (or detached) from the parent process' mount
namespace. This achieve point 1 from above.

`mount_wrap` allows a user to bind (and unbind) a directory within his/her home directory to a mount point within
his/her home directory.

```bash
$ mount_wrap --help
Usage: mount_wrap OLD_DIR NEW_DIR
       mount_wrap -u MOUNT_DIR
```

This achieve point 2.

Before we go any further, I suggest placing a copy of these binaries in a 'safe' location:

```bash
$ mkdir -p $HOME/bin
$ cp `IFS=":" read -ra _go_path <<< "$GOPATH"; echo $_go_path`/bin/{mount_wrap,unshare_mounts} $HOME/bin
```

We also need to make both setuid:

```bash
$ sudo chown root:root $HOME/bin/{mount_wrap,unshare_mounts}
$ sudo chmod u+s $HOME/bin/{mount_wrap,unshare_mounts}
$ ls -la $HOME/bin/{mount_wrap,unshare_mounts}
-rwsr-xr-x 1 root root 3047448 Mar 19 23:18 /home/myitcv/bin/mount_wrap
-rwsr-xr-x 1 root root 2571288 Mar 19 23:18 /home/myitcv/bin/unshare_mounts

```

Finally ensure that `$HOME/bin` is on our `PATH`:

```bash
$ export PATH=$HOME/bin:$PATH # I recommend adding this to your .bashrc
```

That's the groundwork out of the way; let's test this out.

## Testing the setup

In my development environment, I effectively want isolation per terminal (I use `xterm`). Very simply therefore I want
to ensure that when I spawn a new terminal, the bash instance running within it has a separate mount namespace from its
parent and all other terminals. Let's create a couple such terminals:

```bash
$ xterm -e $HOME/bin/unshare_mounts & # terminal 1
$ xterm -e $HOME/bin/unshare_mounts & # terminal 2
```

Let us refer to the original terminal in which we ran these commands as `terminal 0`. And let us assume we have a
directory we want to map:

```bash
# terminal 0
$ ls $HOME/.gostuff/go1.2.1
bin  pkg  src
```

Now let's create a mount point to try this out:


```bash
# terminal 0
$ mkdir $HOME/blah
$ ls $HOME/blah
```

This new directory is obviously going to be empty.

Now in one of our spawned terminals, `terminal 1` for the sake of argument, let's try an isolated mount:

```bash
# terminal 1
$ mount_wrap $HOME/.gostuff/go1.2.1/ $HOME/blah
$ ls $HOME/blah
bin  pkg  src
```

As you can see, `$HOME/blah` has been mounted as requested and the contents correspond to the contents of
`$HOME/.gostuff/go1.2.1`. Excellent. But what about the other two terminals?

```bash
# terminal 0
$ ls $HOME/blah
```

```bash
# terminal 2
$ ls $HOME/blah
```

Even better. Both show `$HOME/blah` as empty.

The mount we performed in `terminal 1` will be available to the containing bash process and all its child processes
(ignoring for a second we could `unshare` again...), but isolated entirely from other processes running on the same
machine (including the processes running within `terminal 0` and `terminal 2` as we have seen).

Let's move on to a rather more interesting example.


## Example: Go development environment setup (emulating gvm)

This is a very subjective area and so my proposals here should be read more as an example of what *can* be achieved
using the approach described above. For this section, let us assume we don't have a tool like [`gvm`] available to us,
and that instead we have to build our own.

Let us further assume that we have downloaded, compiled and installed various versions of Go as follows:

```bash
$ ls -la $HOME/.gos
total 64
drwxr-xr-x  7 myitcv myitcv  4096 Mar 14 15:09 .
drwxr-xr-x 69 myitcv myitcv 36864 Mar 19 15:04 ..
drwxr-xr-x 12 myitcv myitcv  4096 Mar 14 15:05 go1.0.2
drwxr-xr-x 12 myitcv myitcv  4096 Mar 14 15:03 go1.0.3
drwxr-xr-x 12 myitcv myitcv  4096 Mar 14 15:09 go1.1.2
drwxr-xr-x 12 myitcv myitcv  4096 Feb 28 09:19 go1.2
drwxr-xr-x 12 myitcv myitcv  4096 Mar 12 17:54 go1.2.1
$ ls $HOME/.gos/go1.2.1/bin/go
/home/myitcv/.gos/go1.2.1/bin/go
# each installation has a go binary
```

For simplicity, let us create a different mount point that will drive the version of Go we are using:

```bash
$ mkdir $HOME/gos
```

Now let us define our `PATH` and `GOROOT` environment variables in terms of this new mount point:

```bash
$ export PATH=$HOME/gos/bin:$PATH
$ export GOPATH=$HOME/gos
$ which go || echo "Go is not installed"
Go is not installed
```

If you have a version of Go somewhere on your path already, the output of that last command will show the path. Not a
problem, just bear that in mind as we continue.

How do we start using Go 1.2.1? Simple:

```bash
$ mount_wrap $HOME/.gos/go1.2.1/ $HOME/gos
$ which go
/home/myitcv/gos/bin/go
$ go version
go version go1.2.1 linux/amd64
```


How do we start using Go 1.0.3? You guessed it:


```bash
$ mount_wrap $HOME/.gos/go1.0.3/ $HOME/gos
$ which go
/home/myitcv/gos/bin/go
$ go version
go version go1.0.3
```

*Note we don't need to `umount` here because the `mount` is only a bind*

Hopefully the parallel with variant symlinks is clear. Indeed our calls to `mount_wrap` can be wrapped up in shell
commands/functions to make things easier to call and read. And of course if our terminals were spawned using `unshare`
as we described earlier, the mounts would be restricted to those terminals' respective bash processes (and their
respective child processes).

## Conclusions

I have hopefully demonstrated how using process namespaces to emulate variant symlinks can make the configuration of
one's development environment *much* simpler. Whilst I don't intend to move away from `gvm` an friends right away, I now
at least have the option; with very basic tools at my disposal to make this possible and painless (and arguably more
flexible).

A couple of points in conclusion:

* My testing has only been on Linux, specifically Ubuntu 13.10. Plan9 will clearly allow for something similar, other
  platforms may also. Please add comments below if you have something similar working on Mac OS X, Windows etc.
* As of 2014-03-19, I class this solution as <span style="color:red">'slightly hacky'</span> because of the escalation
  of privileges required. Perhaps security types could comment on the safety (or otherwise) of my approach
* The example outlined above presents something of a chicken and egg problem if you want to avoid installing `gvm` and
  instead use a process namespace-based solution. This can of course be circumvented by using a system install of Go to
bootstrap things (e.g. `sudo apt-get install golang` on Ubuntu)
* Whilst the examples presented above are all Go related, this solution is of course not language specific and could be
  extended, as I have suggested, to `rbenv`, `nvm` etc. as well as their associated package managers. Indeed the good
thing about this solution is that it is no way prescriptive about how to structure your environment/work/packages etc.

Any feedback gratefully received in the comments below.


## Change history<a name="changehistory"></a>

* *2014-03-19* - replace references to `unshare` package (and subsequent `chmod u+s`) with references to `unshare_mounts` command.
  Removes requirement on package being installed but also means we don't have to modify permission of package-installed
file
* *2014-03-19* - change all references to `/home/myitcv` in commands to `$HOME` - allows copy-paste


[FUSE]: http://fuse.sourceforge.net/
[`go-fuse`]: https://github.com/hanwen/go-fuse
[`gvm`]: https://github.com/moovweb/gvm
[`rbenv`]: https://github.com/sstephenson/rbenv
[`nvm`]: https://github.com/creationix/nvm

