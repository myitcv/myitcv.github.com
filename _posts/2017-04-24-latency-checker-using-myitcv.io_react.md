---
date: 2017-04-23
layout: post
title: Latency checker demo using myitcv.io/react
location: London
author: paul
---

With [TJ Holowaychuk](https://twitter.com/tjholowaychuk)'s kind permission, I have recreated his quite beautiful
[Latency Tool](https://latency.apex.sh/) using components written against [`myitcv.io/react`](https://myitcv.io/react),
GopherJS bindings for React. The live hosted version can be found here:

[https://blog.myitcv.io/gopherjs\_examples\_sites/latency/](https://blog.myitcv.io/gopherjs_examples_sites/latency/)

This demo version doesn't actually check latencies for the supplied URL, instead it randomly generates values.

Here's a screenshot to whet your appetite:

<a href="https://blog.myitcv.io/gopherjs_examples_sites/latency/"><img src="{{ site.url }}/images/2017-04-23-latency.png" style="border: solid 1px lightgray;"/></a>

The source code for the React components can be found [on
Github](https://github.com/myitcv/x/blob/master/react/examples/sites/latency/latency.go).
