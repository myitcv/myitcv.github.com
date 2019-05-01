---
date: 2018-08-10
layout: post
title: Go Modules support for GopherJS
location: London
author: paul
---

Introducing [https://github.com/myitcv/gopherjs](https://github.com/myitcv/gopherjs), a fork of
[https://github.com/gopherjs/gopherjs](https://github.com/gopherjs/gopherjs) that includes almost complete [Go
Modules](https://golang.org/cmd/go/#hdr-Modules__module_versions__and_more) support, as well as some other bug fixes and
goodies. The medium to long term plan is to have these changes be merged back into the main repo, but for now they will
be maintained in this fork.

When in module mode, this fork should be used via a `replace`:

```
module mod.com

replace github.com/gopherjs/gopherjs => github.com/myitcv/gopherjs latest
```

The current list of changes found in the https://github.com/myitcv/gopherjs fork includes:

* Almost complete Go Modules support
* Significantly improved test coverage of `gopherjs` via
  [`testscript`](https://godoc.org/github.com/rogpeppe/go-internal/testscript) test scripts
* Quicker and more accurate `gopherjs` builds/installs thanks to a [build artefact
  cache](https://godoc.org/github.com/rogpeppe/go-internal/cache) (similar to that used by `cmd/go`)
* Experimental addition of [`MakeFullWrapper`](https://godoc.org/github.com/myitcv/gopherjs/js#MakeFullWrapper) to
  `github.com/gopherjs/gopherjs/js` (note this should still be imported as `github.com/gopherjs/gopherjs/js`)
* Improved contributor experience:
  * JavaScript shims maintained in `.js` files
  * Node-based tooling to help format/manage the `.js` files
* Various bug fixes

See the [commit log](https://github.com/myitcv/gopherjs/commits/master) for full details.
