#!/usr/bin/env bash

# **START**

export GOPATH=$HOME
export PATH=$GOPATH/bin:$PATH
echo "machine github.com login $GITHUB_USERNAME password $GITHUB_PAT" >> $HOME/.netrc
echo "" >> $HOME/.netrc
echo "machine api.github.com login $GITHUB_USERNAME password $GITHUB_PAT" >> $HOME/.netrc
git config --global user.email "$GITHUB_USERNAME@example.com"
git config --global user.name "$GITHUB_USERNAME"
git config --global advice.detachedHead false
git config --global push.default current

# tidy up if we already have the repos
now=$(date +'%Y%m%d%H%M%S_%N')
githubcli repo renameIfExists $GITHUB_ORG/myfirstgoaction myfirstgoaction_$now
githubcli repo transfer $GITHUB_ORG/myfirstgoaction_$now $GITHUB_ORG_ARCHIVE
githubcli repo create $GITHUB_ORG/myfirstgoaction
githubcli repo renameIfExists $GITHUB_ORG/usingmyfirstgoaction usingmyfirstgoaction_$now
githubcli repo transfer $GITHUB_ORG/usingmyfirstgoaction_$now $GITHUB_ORG_ARCHIVE
githubcli repo create $GITHUB_ORG/usingmyfirstgoaction

# block: action repo
echo github.com/$GITHUB_ORG/myfirstgoaction

# block: action repo url
echo https://github.com/$GITHUB_ORG/myfirstgoaction

# block: usingaction repo
echo github.com/$GITHUB_ORG/usingmyfirstgoaction

# block: usingaction repo url
echo https://github.com/$GITHUB_ORG/usingmyfirstgoaction

# block: setup action
mkdir -p $HOME/scratchpad/myfirstgoaction
cd $HOME/scratchpad/myfirstgoaction
git init -q
git remote add origin https://github.com/$GITHUB_ORG/myfirstgoaction

# block: define action repo root module
go mod init github.com/$GITHUB_ORG/myfirstgoaction

# block: action initial commit
git add go.mod
git commit -q -am 'Initial commit'
git push -q

# block: create action
cat <<EOD > main.go
package main

import (
	"fmt"

	"github.com/sethvargo/go-githubactions"
)

func main() {
	name := githubactions.GetInput("name")
	fmt.Printf("Hello, %v! We are running on %v; Hooray!\n", name, platform())
}
EOD

cat <<EOD > platform_linux.go
package main

func platform() string {
	return "linux"
}
EOD

cat <<EOD > platform_darwin.go
package main

func platform() string {
	return "macOS"
}
EOD

cat <<EOD > platform_windows.go
package main

func platform() string {
	return "windows"
}
EOD

cat <<EOD > action.yml
name: 'Greeter'
description: 'Print a platform-aware greeting to the user'
inputs:
  name:
    description: 'The name of the user'
    required: true
runs:
  using: 'node12'
  main: 'index.js'
EOD

cat << EOD > index.js;
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
EOD

# dummy run
go run .
export INPUT_NAME=Helena

# block: main out
go run .

# block: action main
cat main.go

# block: platform linux
cat platform_linux.go

# block: action yml
cat action.yml

# block: action indexjs
cat index.js

# block: commit and tag action
git add -A
git commit -q -am 'Define action'
git push -q
actionCommit=$(git rev-parse HEAD)

# block: setup usingaction
mkdir -p $HOME/scratchpad/usingmyfirstgoaction
cd $HOME/scratchpad/usingmyfirstgoaction
git init -q
git remote add origin https://github.com/$GITHUB_ORG/usingmyfirstgoaction

# block: define usingaction repo root module
go mod init github.com/$GITHUB_ORG/usingmyfirstgoaction

# block: usingaction initial commit
git add go.mod
git commit -q -am 'Initial commit'
git push -q

# block: use action
mkdir -p .github/workflows
cat <<EOD > .github/workflows/test.yml
on: [push, pull_request]
name: Test
jobs:
  test:
    strategy:
      matrix:
        platform: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: \${{ matrix.platform }}
    steps:
    - uses: actions/setup-go@9fbc767707c286e568c92927bbf57d76b73e0892
      with:
        go-version: '1.14.x'
    - name: Display a greeting
      uses: $GITHUB_ORG/myfirstgoaction@$actionCommit
      with:
        name: Helena
EOD

# block: usingaction workflow
cat .github/workflows/test.yml


# block: commit and tag usingaction
git add -A
git commit -q -am 'Use action'
git push -q

# block: version details
go version
