---
date: 2017-08-21
layout: post
title: Golang UK Talk on Go and React
location: London
author: paul
---

Last Thursday, 17 Aug, I gave a talk at [Golang UK 2017](https://www.golanguk.com/), entitled _"Creating interactive
frontend apps with GopherJS and React."_

The slides are available
[here](http://blog.myitcv.io/gopherjs_examples_sites/present/?url=https://raw.githubusercontent.com/myitcv/react/master/_talks/2017/golang_uk.slide&hideAddressBar=true).
YouTube video to follow.

The slides are loaded by a Go web app version of the [`present`
command](https://godoc.org/golang.org/x/tools/cmd/present). This app works with any publicly accessible slide deck. For
example, [@francesc](https://twitter.com/francesc)'s [_State of Go_ talk from May](
http://blog.myitcv.io/gopherjs_examples_sites/present/?url=https://raw.githubusercontent.com/golang/talks/master/2017/state-of-go-may.slide&hideAddressBar=true).

[The app](https://github.com/myitcv/react/tree/master/examples/sites/present) is very basic, probably has bugs. Next
stage is to re-write the [Javascript part of `present`](https://github.com/golang/tools/tree/master/cmd/present/static)
in Go.
