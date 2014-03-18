---
date: 2014-03-18
layout: post
title: Using process namespaces to implement variant symlinks
location: London
author: paul
---

This article covers my attempts to implement behaviour akin to variant symlinks within my development environment. It
charts a failed attempt at building a fuse-based file system solution through to a working (but somewhat hacky) solution
that uses Linux process namespaces.

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
$ export PATH=/home/myitcv/gostuff/\$GO_VERSION/bin:$PATH
```

_(the backslash here being the way that Bash allows you to delay the evaluation of the variable that follows; useful for
example in the setting of `PS1`)_

Hence how I first stumbled across variant symlinks...

## Variant symlinks - background

The idea behind [variant
symlinks](https://wiki.freebsd.org/200808DevSummit?action=AttachFile&do=get&target=variant-symlinks-for-freebsd.pdf) is
as follows (borrowing liberally from the example presented in the paper) - assume `bash` shell on Linux Ubuntu 13.10
throughout:

```bash
$ echo "contents of bar" > bar; echo "contents of baz" > baz
$ ln -s ’${XXX}’ foo
$ ls -l foo
lrwxr-xr-x 1 brooks wheel ... foo -> ${XXX}
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
[`go-fuse`]. The idea was write a FUSE file system that would serve as follows:

```
serve ->
  PathNodeFs ->
    VarSymFs ->
      LoopbackFileSystem
```

A [`PathNodeFs`](http://godoc.org/github.com/hanwen/go-fuse/fuse/pathfs#NewPathNodeFs) would resolve from inodes to
paths (this is FUSE's interface); this would then delegate a call to `VarSymFs`, the bit I was writing. Using the
provided [`*fuse.Context`](http://godoc.org/github.com/hanwen/go-fuse/fuse#Context) `VarSymFs` would interrogate the
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
Just bear in mind that it was a very rough cut... that didn't work fully!

## Process namespaces

My implementation focus until this point had been on developing a solution around variant symlinks. However a [chance
comment](https://groups.google.com/d/msg/golang-nuts/WhI4Ok_51v0/RZfo5VDqNpMJ) in response a post requesting suggestions
from [the Go community](https://groups.google.com/forum/#!forum/golang-nuts) sent me in another direction entirely.

Aram's comment essentially refers to [the use of name spaces in Plan 9](http://plan9.bell-labs.com/sys/doc/names.html),
a document well worth the read. But here I fell upon another fairly fundamental problem: I'm not using Plan 9.
Thankfully the Linux kernel [also has a namespace implementation](http://lwn.net/Articles/531114/) - I am unclear
on how exactly the two compare. The series of articles goes on to suggest [all manner of ways that process namespaces
can be used](http://www.ibm.com/developerworks/linux/library/l-mount-namespaces/index.html).

But my interest was fixed on one aspect of process namespaces in particular: [mount
namespaces](http://lwn.net/2001/0301/a/namespaces.php3).

> Mount namespaces (CLONE_NEWNS, Linux 2.4.19) isolate the set of filesystem mount points seen by a group of processes.
> Thus, processes in different mount namespaces can have different views of the filesystem hierarchy.

Whilst not driven by environment variables the process isolation achieves exactly the same behaviour (at least as far as
I am concerned).

## Conclusions

This is not a silver bullet:

* Not cross platform

[FUSE]: http://fuse.sourceforge.net/
[`go-fuse`]: https://github.com/hanwen/go-fuse
[`gvm`]: https://github.com/moovweb/gvm
[`rbenv`]: https://github.com/sstephenson/rbenv
[`nvm`]: https://github.com/creationix/nvm

