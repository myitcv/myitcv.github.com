---
date: 2013-03-10
layout: post
title: Using figaro and bash for a smoother development config environment
location: San Francisco
author: paul
tags:
- coding
- ruby
- rails
---

_**Update 2013-03-12:** replaced the rather fragile piping of commands with a simple ruby script to extracting the config_

_**Update 2014-02-24:** I have now switched to using [`smartcd`](https://github.com/cxreg/smartcd) in preference to the
aproach described below_

<hr/>

Environment variables have for a long time been the source of configuration data for (many) Unix-based applications.

[Figaro](https://github.com/laserlemon/figaro) is a great `gem` that makes it easy to combine environment variables with
Yaml-based overrides.

> Open sourcing a Rails app can be a little tricky when it comes to sensitive configuration information like Pusher or
> Stripe credentials. You don't want to check private credentials into the repo but what other choice is there?

> Figaro provides a clean and simple way to configure your app and keep the private stuff… private.

Here I outline a neat method by which per project environment variables can be set using Bash to combine with the
standard figaro mode of operation.

We start by creating a secrets file in our `$HOME` directory, well away from any Rails projects:

```ini
# $HOME/.web_app_secrets

[project-name]
VAR_1=test
VAR_2=again
```

The format here is very simple. `project-name` should correspond to the directory which contains the Rails project in
question. For example if our Rails project is found in `$HOME/dev/omniauth-google-oauth2-example` we would be
`omniauth-google-oauth2-example` in place of `project-name`. The variable names should be [capitalised by
convention](http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_03_02.html#sect_03_02_02) .

Clearly this configuration file could get quite long and contain multiple sections and could contain comments:

```ini
# $HOME/.web_app_secrets

# comments can only be used on their own line
[project-1-name]
VAR_1=test
VAR_2=again

[project-2-name]
# spacing around the '=' is optional
VAR_1  =  test
# it's the first non-whitespace character that counts
VAR_2 = first

[project-3-name]
VAR_1=test
# indeed it's everything that's after the first non-whitespace character that counts
VAR_2 = we want everything from this line

```

Now let's write a helper script to pull out a named block of variables and get them in a format that bash can consume to
set environment variables:

```ruby
#!/usr/bin/env ruby

# This file is $HOME/bin/config_select
# first line of the file must include the #!

require 'parseconfig'

raise "Two required arguments: file group" unless [2].include? ARGV.count

(file,group) = ARGV
config = ParseConfig.new(file)
config[group].each_pair do |key, value|
  puts <<-LINE
export #{key}="#{value}"
LINE
end
```

If we run this on our `$HOME/.web_app_secrets` file to pull out the `project-3-name` config:

```bash
$HOME/bin/config_select $HOME/.web_app_secrets project-3-name
```

we get the following output as expected:

```bash
export VAR_1="test"
export VAR_2="we want everything from this line"
```

Now we need to hook up Bash so that whenever we `cd` to a directory that contains a figaro-enabled project it sources
the appropriate environment variables.

A standard figaro installation creates a `config/application.yml` file (see the [omnitauth example for
details](/2013/02/19/omniauth-google-oauth2-example.html)) . Hence we can test for the existence of this file in our
hook.

Edit `$HOME/.bashrc` to include the following (taking care if you have already aliased `cd`):

```bash
# $HOME/.bashrc
# ...

alias cd=_cd_special

_cd_special ()
{
  "cd" $1
  if [ -e "$PWD/config/application.yml" ] # we are using figaro
  then
    selector=`basename $PWD`
    eval $($HOME/bin/config_select $HOME/.web_app_secrets $selector)
  fi
}

# ...
```

So how do we now use these variables in our code? Here's an example:

```ruby
# config/initializers/oauth.rb

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV['VAR_1'],
    ENV['VAR_2'],
    {name: "google_login", approval_prompt: ''}
end
```

Furthermore, these environment variables can be overridden within the project config:

```yaml
# config/application.yml

VAR_1: "value"
```

Notice the different style of setting values (see the [Wikipedia](http://en.wikipedia.org/wiki/YAML) for a definitive
reference on YAML).

There are further benefits to using figaro when it comes to deploying to [Heroku](http://www.heroku.com/) but this is
covered in the [project's README](https://github.com/laserlemon/figaro)