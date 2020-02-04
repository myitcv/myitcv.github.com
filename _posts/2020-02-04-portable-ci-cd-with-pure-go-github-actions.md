---
date: 2020-02-04
layout: post
title: Portable CI/CD with pure Go GitHub Actions
location: London
author: paul
---

I recently converted the [`govim`](https://github.com/govim/govim) project to use [GitHub
Actions](https://github.com/features/actions). The move away from [TravisCI](https://travis-ci.org/) was largely
motivated by more generous concurrency limits ([GitHub’s
20](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/about-github-actions#usage-limits)
jobs vs TravisCI's 5), faster job startup times, and solid cross-platform support. But there was also the promise of
making it easy to extend workflows with composable third-party actions. This post  demonstrates how to write
cross-platform, pure Go GitHub actions that you can  use in your workflows and share with others. But first we start by
motivating the real problem we are trying to solve.

### Wait, there's a problem with GitHub Actions?

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Did you know that malicious code can be inserted into any GitHub action, even those which are tagged ?<br>I wrote a blog post about it:<a href="https://t.co/PNq2MwaMUN">https://t.co/PNq2MwaMUN</a> cc <a href="https://twitter.com/github?ref_src=twsrc%5Etfw">@github</a> <a href="https://t.co/gUevMJOS6n">pic.twitter.com/gUevMJOS6n</a></p>&mdash; Julien Renaux (@julienrenaux) <a href="https://twitter.com/julienrenaux/status/1208046853780062210?ref_src=twsrc%5Etfw">December 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

[Julien Renaux's](https://twitter.com/julienrenaux) blog post linked from that tweet does a good job of laying out one
of the core problems with GitHub Actions. The story goes roughly like this:

* someone writes and open-sources an action that requires secret credentials, e.g. DockerHub access token
* lots of people start using the action via directives like `uses: good/action@v1` because it's well written and useful
* original author welcomes a new maintainer on board
* somehow existing action version tags get moved, pointing to malicious code that steals secrets (any maintainer can
  update a branch or a tag)

Hence the specific advice is to use a commit hash to partially mitigate this risk:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">That’s why you need to specify the exact version (action@sha1) you want to use, so further changes won’t impact you.</p>&mdash; Alain Hélaïli (@AlainHelaili) <a href="https://twitter.com/AlainHelaili/status/1205238489056501761?ref_src=twsrc%5Etfw">December 12, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

_It is somewhat unfortunate at best that this isn't the default advice in the official documentation; worth noting it
doesn't defend against the commit disappearing._

The problems don't stop there, because there is also the risk that transitive dependencies can do malicious things too:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">There is also a risk that the transitive dependencies can do malicious things.<a href="https://t.co/juffjxwxIr">https://t.co/juffjxwxIr</a></p>&mdash; DrSensor👹 (@dr\_sensor) <a href="https://twitter.com/dr_sensor/status/1208098900747284480?ref_src=twsrc%5Etfw">December 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

On top of this, it's not made particularly clear to users that every action they use in their workflow is given implicit
access to an access token that has fairly [wide-ranging read-write access to the host
repository](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/authenticating-with-the-github_token#permissions-for-the-github_token).

So we clearly have a software dependency problem here.

### Why Go?

[Russ Cox](https://twitter.com/_rsc) has [repeatedly](https://research.swtch.com/deps) [written](https://twitter.com/_rsc/status/1088109141409837063) about "Our Software Dependency Problem." The basic premise of those articles is that "software dependencies carry with them serious risks that are too often overlooked." Whilst Russ' articles raise awareness of the risks and encourage more investigation of solutions (and I strongly encourage you to read the article in full), the bottom line is that Go has a comprehensive solution to the major problems outlined, via the [Go Module Mirror](https://proxy.golang.org/), [Index](https://index.golang.org/), and [Checksum Database](https://sum.golang.org/), that ultimately results in the `go` command referencing an auditable checksum database to authenticate modules. Coupled with the [minimum version selection](https://research.swtch.com/vgo-mvs) property of Go modules, we have ourselves a verifiable way to run exactly the (third party) action code we  previously audited (you all audit your dependencies, right?)


### The slight wrinkle

At the time of writing (2020/02/04), GitHub does not natively support writing actions in Go:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Hi <a href="https://twitter.com/github?ref_src=twsrc%5Etfw">@github</a> - please can you provide a native way to write/use actions written in Go, that would allow me to do something like:<br><br> uses: $package@$version<br><br>which would then use <a href="https://t.co/fGOHqwoWSA">https://t.co/fGOHqwoWSA</a> for resolution, and <a href="https://t.co/hqG8e8gGf6">https://t.co/hqG8e8gGf6</a> for verification. Thanks <a href="https://twitter.com/hashtag/golang?src=hash&amp;ref_src=twsrc%5Etfw">#golang</a></p>&mdash; Paul Jolly (@_myitcv) <a href="https://twitter.com/_myitcv/status/1224288510053691393?ref_src=twsrc%5Etfw">February 3, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Instead, you have [the
choice](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/about-actions) of writing
either:

* Docker container-based actions (Linux only; Docker also works on Windows but the official GitHub Actions docs don't
  yet list that as "supported")
* JavaScript-based actions (Linux, macOS, Windows)

With the goal of being fully cross-platform in mind, Docker actions are therefore ruled out.

I fell out of love with JavaScript a long time ago, a process that was accelerated by my working on
[GopherJS](https://github.com/gopherjs/gopherjs) (a compiler from Go to JavaScript). Having to return to its "unique"
approach didn't exactly fill me with glee, but given the current state of affairs there was, seemingly, no other option.
Indeed, the first couple of iterations of writing pure Go GitHub actions  used GopherJS and the [Go's WebAssembly
port](https://github.com/golang/go/wiki/WebAssembly). However, both fell a long way short because neither support
fork/exec syscalls.

### The solution

With half a mind to GitHub eventually shipping native support for Go actions, I instead landed on a solution that uses a
light JavaScript wrapper around the `go` command. Let's explore that approach by writing an action.

But first, let's start by defining what our toy action will do. Incorporated into a workflow, this toy action will take
a single input, the user's name, and will output a line like:

```
Hello, Helena! We are running on linux; Hooray!
```

(obviously adapted to the name of the user and the platform on which our workflow is running).

### Creating a module for our action

The documentation for [`cmd/go`](https://golang.org/cmd/go/#hdr-Modules__module_versions__and_more) says of modules:

> A module is a collection of related Go packages. Modules are the unit of source code interchange and versioning.

The is precisely the definition we are after when it comes to GitHub Actions: we want users of the action to express
their dependency on semver versions of our action.

We start therefore by creating a module:

```
$ go mod init github.com/myitcv/myfirstgoaction
```

Before we define the action itself, we briefly discuss a key building block: the GitHub Actions API.

### GitHub Actions API

GitHub Actions has an [API for action
authors](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/development-tools-for-github-actions)
which is published as an [official GitHub Actions SDK for Node.js](https://github.com/actions/toolkit). [Seth
Vargo](https://twitter.com/sethvargo) has put together an [unofficial GitHub Actions SDK for
Go](https://github.com/sethvargo/go-githubactions) that "provides a Go-like interface for working with GitHub Actions."
Thank you, Seth!

Briefly skimming the [SDK documentation](https://pkg.go.dev/github.com/sethvargo/go-githubactions?tab=doc), it's clear
to see how we will be [getting our input](https://pkg.go.dev/github.com/sethvargo/go-githubactions?tab=doc#GetInput),
the name of the user:

```
// GetInput gets the input by the given name.
func GetInput(i string) string
```

We now have the relevant pieces in place to define our action.

### The Go code

The Go code is now, therefore, the simplest part of this action's definition.

```go
$ cat main.go
package main

import (
	"fmt"

	"github.com/sethvargo/go-githubactions"
)

func main() {
	name := githubactions.GetInput("name")
	fmt.Printf("Hello, %v! We are running on %v; Hooray!\n", name, platform())
}
```

The platform-specific bit we will put behind build constrained files to demonstrate that aspects works too:

```go
$ cat platform_linux.go
package main

func platform() string {
	return "linux"
}
```

Hopefully the contents for `platform_darwin.go` and `platform_windows.go` are obvious.

### Creating an action metadata file

The next step is to create an action metadata file:

```yaml
$ cat action.yml
name: 'Greeter'
description: 'Print a platform-aware greeting to the user'
inputs:
  name:
    description: 'The name of the user'
    required: true
runs:
  using: 'node12'
  main: 'index.js'
```

Notice how we are running using NodeJS with an entry point of `index.js`; we talk about that next.

### The `index.js` entry point

Whilst we await native support for pure Go GitHub Actions, the simplest solution to running Go actions is a thin NodeJS
wrapper around `cmd/go`. For now this should be copy-pasted for each action you create:

```javascript
$ cat index.js
"use strict";

const spawn = require("child_process").spawn;

async function run() {
  var args = Array.prototype.slice.call(arguments);
  const cmd = spawn(args[0], args.slice(1), {
    stdio: "inherit",
    cwd: __dirname
  });
  const exitCode = await new Promise((resolve, reject) => {
    cmd.on("close", resolve);
  });
  if (exitCode != 0) {
    process.exit(exitCode);
  }
}

(async function() {
  const path = require("path");
  await run("go", "run", ".");
})();
```

Clearly copy-pasting this boilerplate, even in the short term, is not ideal. I am looking at ways to simplify and
automate this step using a Go tool (ideas also welcomed).

### Using our action

Now let's switch to creating a project that uses the Greeter action in one of its workflows:

```yaml
$ go mod init github.com/myitcv/usingmyfirstgoaction
$ cat .github/workflows/test.yml
on: [push, pull_request]
name: Test
jobs:
  test:
    strategy:
      matrix:
        platform: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.platform }}
    steps:
    - uses: actions/setup-go@9fbc767707c286e568c92927bbf57d76b73e0892
      with:
        go-version: '1.14.x'
    - name: Display a greeting
      uses: myitcv/myfirstgoaction@d085dddfc01ecb14af3778b49dd8672fcd0e7652
      with:
        name: Helena
```

We specify a matrix of all platforms to demonstrate our action truly is cross-platform.

Given GitHub Actions don't natively support Go actions, and as we demonstrated in our `index.js` wrapper, we have to use
the `go` command. We therefore must have [`actions/setup-go`](https://github.com/actions/setup-go) as our first step in
any workflow that uses a Go action of this sort (until native actions come along).

Finally, both `uses: actions/setup-go` and `uses: myitcv/myfirstgoaction` specify specific commits, per advice earlier
in this post.

That's it! Let's commit, push and watch the build succeed!

![A successful build](/images/2020-02-04-build-success.png "A successful build")

### So what would native actions look like?

There are a few problems with the approach outlined above:

1. we need to explicitly install Go
2. we need to copy-paste our `index.js` wrapper for each Go action we create
3. we are not relying on the Go module proxy when using the action and hence have to specify a commit rather than a
   semver version

Points 1 and 2 clearly disappear when native support is added.

Point 3 is particularly brittle because commits themselves can disappear from GitHub (force pushing to `master`, commit
no longer referenced by any tags or branches, gets cleaned up).

Therefore, given point 3 we ideally would use our action in a workflow in the following way:

```yaml
    - name: Display a greeting
      uses: github.com/myitcv/myfirstgoaction@v1.0.0
      with:
        name: Helena
```

such that when running the action, GitHub's infrastructure:

* creates a temporary module
* resolves the Go package `github.com/myitcv/myfirstgoaction` at version `v1.0.0` via
  [proxy.golang.org](https://proxy.golang.org)
* runs the action via `go run github.com/myitcv/myfirstgoaction`

_Notice, the package path and module path being equal is just a coincidence of this example_

### Conclusion

Go provides some novel solutions to the problems of software dependencies. In this article I have demonstrated one way
in which pure Go actions can be written today (whilst we await native support from GitHub), leveraging the benefits and
protections of the Go Module Mirror, Index, and Checksum Database. Ultimately we all need to review our software
dependencies, but at least Go makes it easier to know that the world hasn't changed under our feet from build-to-build.

### Appendix

All of the source code used in this blog post is available on GitHub:

* [github.com/myitcv/myfirstgoaction](https://github.com/myitcv/myfirstgoaction)
* [github.com/myitcv/usingmyfirstgoaction](https://github.com/myitcv/usingmyfirstgoaction)

With thanks to [Daniel Martí](https://twitter.com/mvdan_) for reviewing this post.
