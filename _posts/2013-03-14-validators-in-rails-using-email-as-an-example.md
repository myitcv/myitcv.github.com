---
date: 2013-03-14
layout: post
title: Email validation against RFC2822 using Rails ActiveModel::EachValidator
location: San Francisco
author: paul
tags:
- coding
- ruby
- rails
---

Often when you create a `user` model you are faced with the question of "how do I check whether the email address they
supplied is valid?"

This question needs to be broken down further:

* Is the supplied email address even a valid format?
* Can the user confirm they 'own' the email address?

The second point will be dealt with in a later post, and so to the first.

The ultimate reference on what constitutes a valid email format is [RFC2822](http://www.ietf.org/rfc/rfc2822.txt),
specifically ??&sect; 3.4.1. Addr-spec specification??. This section defines the
[syntax](http://en.wikipedia.org/wiki/Syntax_(programming_languages)) of email addresses using a parsing expression
grammar. Quoting directly from the RFC:

```
ddr-spec        =       local-part "@" domain

local-part      =       dot-atom / quoted-string / obs-local-part

domain          =       dot-atom / domain-literal / obs-domain

domain-literal  =       [CFWS] "[" *([FWS] dcontent) [FWS] "]" [CFWS]

dcontent        =       dtext / quoted-pair

dtext           =       NO-WS-CTL /     ; Non white space controls

                        %d33-90 /       ; The rest of the US-ASCII
                        %d94-126        ;  characters not including "[",
                                        ;  "]", or "\""
```

What do we do with this grammar? Well if we were feeling brave we could use use
[treetop](https://github.com/nathansobo/treetop) to generate a parser, a parser which we could then use to parse (and
therefore validate the format of) email addresses we receive from our users.

Thankfully, the `mail` gem has done all this hard work for us. For those interested in viewing the treetop grammar,
[take a look here](https://github.com/mikel/mail/blob/master/lib/mail/parsers/rfc2822.treetop)

Let's cut straight to an example. First load `irb` on the command line and then:

```ruby
require 'mail'
```

First let's see what happens with an invalid address:

```ruby
parsed = Mail::Address.new("@P__A__J")
```

You should see that a `Mail::Field::ParseError` exception is raised. Good start, because this is definitely not valid (except in Twitter world)

How about a valid email address?

```ruby
parsed = Mail::Address.new("paul@myitcv.org.uk")
```

No exception, and indeed we now have a `Mail::Address` object:

```
 => #<Mail::Address:87073640 Address: |paul@myitcv.org.uk| >
```

Do we have a valid address? Yes we do, but be careful:

```ruby
parsed = Mail::Address.new("paul")
```

is also valid. It's a local address with no domain portion. So more completely we should check:

```ruby
address = "paul@myitcv.org.uk"
parsed = Mail::Address.new(address)
puts "Valid" if parsed.address == address && parsed.local != address
```

This outputs `Valid` as expected. We have a fully qualified email address.

## Checking email formats in Rails models

How then do we use this in our Rails application? Let's build a basic example from the ground up.

```bash
rails new email_validator_example
cd email_validator_example
rails generate model user name:string email:string
rake db:migrate
```

At this stage we have no validation on either the `name` or `email` fields of our `user`.

Rails provides means of validating fields using [regular expressions](http://api.rubyonrails.org/classes/ActiveModel/Validations/HelperMethods.html#method-i-validates_format_of) but our validation (as we saw above) is slightly more involved. We are in fact going to define an [`ActiveModel::EachValidator`](http://api.rubyonrails.org/classes/ActiveModel/EachValidator.html)

First let's create a directory to hold out validators:

```bash
mkdir app/models/validators
```

We need to ensure this directory is autoloaded when our Rails application starts:

```ruby
# config/application.rb

# ...
module EmailValidatorExample
  class Application < Rails::Application

    #...

    config.autoload_paths += %W(#{config.root}/app/models/validators)

```

Now let's ensure the `mail` gem is included in our application:

```ruby
# Gemfile

# ...

gem 'mail'

```

Ensure that the requisite gems are installed:

```bash
bundle install
```

Now let's create our email validator:

```ruby
# app/models/validators/email_validator.rb

require 'mail'

module Validators
  class EmailValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      begin
        parsed = Mail::Address.new(value)
      rescue Mail::Field::ParseError => e
      end
      record.errors.add attribute, "is not valid" unless !parsed.nil? && parsed.address == value && parsed.local != value #cannot be a local address
    end
  end
end
```

You can see our class `EmailValidator` is placed within the `Validators` module and derives from `ActiveModel::EachValidator`. As we saw earlier, a badly formed email address raises an error so we need to handle that. The final line captures the error cases in the `unless` condition.

Time to add this to our model:

```ruby
# app/models/user.rb

class User < ActiveRecord::Base
  include Validators

  attr_accessible :email, :name
  validates :email, :on => :update, :'validators/email' => true
  validates :email, :on => :create, :allow_nil => true, :'validators/email' => true
end
```

The only line worth explaining here is the apparently double-entry for `validates :email`. The second line allows nil to be a valid value when we first create a `user`, but ensures that if a value is set then the email address is of a valid format.

Time to give this a test in `rails console`:

```
$ rails console
Loading development environment (Rails 3.2.12)
1.9.3-p374 :001 > User.all
  User Load (0.2ms)  SELECT "users".* FROM "users"
 => []
1.9.3-p374 :002 > u = User.new
 => #<User id: nil, name: nil, email: nil, created_at: nil, updated_at: nil>
1.9.3-p374 :003 > u.valid?
 => true
1.9.3-p374 :004 > u.email = "@blah"
 => "@blah"
1.9.3-p374 :005 > u.valid?
 => false
1.9.3-p374 :006 > u.save
   (0.1ms)  begin transaction
   (0.2ms)  rollback transaction
 => false
1.9.3-p374 :007 > u.email = nil
 => nil
1.9.3-p374 :008 > u.valid?
 => true
1.9.3-p374 :009 > u.save
   (0.3ms)  begin transaction
  SQL (30.8ms)  INSERT INTO "users" ("created_at", "email", "name", "updated_at") VALUES (?, ?, ?, ?)  [["created_at", Thu, 14 Mar 2013 22:25:44 UTC +00:00], ["email", nil], ["name", nil], ["updated_at", Thu, 14 Mar 2013 22:25:44 UTC +00:00]]
   (18.6ms)  commit transaction
 => true
1.9.3-p374 :010 > u.email = "paul@myitcv.org.uk"
 => "paul@myitcv.org.uk"
1.9.3-p374 :011 > u.valid?
 => true
1.9.3-p374 :012 > u.save
   (0.3ms)  begin transaction
   (0.0ms)  UPDATE "users" SET "email" = 'paul@myitcv.org.uk', "updated_at" = '2013-03-14 22:25:58.598365' WHERE "users"."id" = 4
   (4.4ms)  commit transaction
 => true
1.9.3-p374 :013 > User.all
  User Load (0.9ms)  SELECT "users".* FROM "users"
 => [#<User id: 4, name: nil, email: "paul@myitcv.org.uk", created_at: "2013-03-14 22:25:44", updated_at: "2013-03-14 22:25:58">]
1.9.3-p374 :014 >
```

## Is this code available anywhere?

As always, there is [a repository on GitHub](https://github.com/myitcv/email_validator_example) .
