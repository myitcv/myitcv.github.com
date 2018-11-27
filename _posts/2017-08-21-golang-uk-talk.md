---
date: 2017-08-21
layout: post
title: Golang UK Talk on Go and React
location: London
author: paul
---

On Thursday, 17 Aug, I gave a talk at [Golang UK 2017](https://www.golanguk.com/), entitled _"Creating interactive
frontend apps with GopherJS and React."_ This talk builds on [an earlier blog
post](https://blog.myitcv.io/2017/04/16/myitcv.io_react-gopherjs-bindings-for-react.html) and the [README for
`myitcv.io/react`](https://github.com/myitcv/x/blob/master/react/_doc/README.md).

<p>
<a href="https://youtu.be/emoUiK-GHkE"><img src="/images/youtube.png" style="width: 40px"></a>&nbsp;<a href="https://youtu.be/emoUiK-GHkE">Video</a>
</p>
<p>
<a href="https://blog.myitcv.io/gopherjs_examples_sites/present/?url=https://raw.githubusercontent.com/myitcv/x/master/react/_talks/2017/golang_uk.slide&hideAddressBar=true"><img src="/images/gopher.png" style="width: 40px"></a>&nbsp;<a href="https://blog.myitcv.io/gopherjs_examples_sites/present/?url=https://raw.githubusercontent.com/myitcv/x/master/react/_talks/2017/golang_uk.slide&hideAddressBar=true">Slides</a>
</p>

The slides are loaded by a browser-based version (compiled with GopherJS) of the [`present`
command](https://godoc.org/golang.org/x/tools/cmd/present). This app works with any publicly accessible slide deck. For
example, [@francesc](https://twitter.com/francesc)'s [_State of Go_ talk from May](
https://blog.myitcv.io/gopherjs_examples_sites/present/?url=https://raw.githubusercontent.com/golang/talks/master/2017/state-of-go-may.slide&hideAddressBar=true).

[The app](https://github.com/myitcv/x/tree/master/react/examples/sites/present) is very basic, probably has bugs. Next
stage is to re-write the [Javascript part of `present`](https://github.com/golang/tools/tree/master/cmd/present/static)
in Go.
