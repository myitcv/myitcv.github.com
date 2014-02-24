---
date: 2013-05-31
layout: post
title: Creating my first Rails Application Template
location: London
author: paul
---

It has been a while since my last post, some I'm going to make this one about something that has long been on the
back-burner: writing my own [Rails Application Template](http://guides.rubyonrails.org/rails_application_templates.html)

As you will see from [the project on GitHub](https://github.com/myitcv/rails_templates/blob/master/default.rb) (I have
linked to the template file itself) the process of creating a template is relatively straightforward.

`default.rb` specifically supports the following gems:

* haml (and Textile support)
* Twitter Bootstrap CSS (SASS version), Bootstrap Forms and Font Awesome
* AASM for state machines
* rolify and cancan for role and authorisation support
* omniauth (the Google OAuth2 strategy) for authentication
* figaro (this could actually be removed now that I'm using AWS)
* Draper support for decorators

It additionally preconfigures the following:

* Initialises a git repository and commits an initial version of the code
* A default root to a basically empty view + controller `home#index`
* A basic Bootstrap fixed layout, with a navbar that includes a right-aligned signin/out menu
* Configuration for `action_mailer` to use smtp via Google
* A pre-canned `user` model, the complements the `omniauth` and AASM setup
* The application requires a user to be logged in by default, except for `home#index` and the `sessions` controller

This template uses the [figaro and
bash](/2013/03/10/using-figaro-and-bash-for-a-smoother-development-config-environment.html) config method I described in
an earlier post (i.e. secrets, passwords etc. passed in via `ENV` variables).

## Usage

Let's assume we want to create a new rails app called `APPNAME`. Once the `~/.web_app_secrets` for `APPNAME` are in
place, I simply need to run:

```bash
rails new APPNAME -m https://raw.github.com/myitcv/rails_templates/master/default.rb
```

change into the new directory and off we go.

## Outstanding issues

This is a very basic start point. There are many things the template does not do (for example, it does nothing with RVM,
and instead uses your current/default version and gemset), but this for me is enough to generally get me going on a
usable and working footing.


