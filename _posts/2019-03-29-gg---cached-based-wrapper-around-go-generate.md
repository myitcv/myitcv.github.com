---
date: 2019-03-29
layout: post
title: gg - cache-based wrapper around go generate
location: London
author: paul
---

[`gg`](https://godoc.org/myitcv.io/cmd/gg) is a cache-based wrapper around `go generate`.

Like `go generate`, `gg` understands `//go:generate` directives. But unlike `go generate`, `gg`:

* understands the dependency graph between packages to be generated, including the generators themselves
* repeatedly runs `//go:generate` directives in a package until a fixed point is reached, allowing generators to chain
  together
* caches generated artefacts, making subsequent runs with the same inputs extremely fast (because the `//go:generate`
  directives do not need to be re-run)
* understands generator flags prefixed with `-infiles:` to declare glob patterns of files the directive will consume
* understands generator flags prefixed with `-outdir:` to mean that the directive will generate files to the named
  directory in addition to the current package's directory
* has a special `//go:generate:gg` directive which allows code generation to `break` under certain conditions

More details [in the docs](https://godoc.org/myitcv.io/cmd/gg).

I also gave a talk at [GoSheffield](https://www.meetup.com/GoSheffield/):

<p>
<a href="https://talks.godoc.org/github.com/myitcv/talks/2019-02-07-code-generation/main.slide#1"><img src="/images/gopher.png" style="width: 30px"></a>&nbsp;<a href="https://talks.godoc.org/github.com/myitcv/talks/2019-02-07-code-generation/main.slide#1">GoSheffield Slides</a>
</p>

As ever, contributions are very much welcome in the form of feedback, issues and PRs [over in the GitHub
repo](https://github.com/myitcv/x).


