---
date: 2013-06-25
layout: post
title: Finding 'low use' contacts - Google Contacts API and GMail IMAP meet
location: London
author: paul
tags:
- coding
- ruby
- rails
- oauth2
- google
- api
- imap
- contacts
---

My address book contacts a number of contacts I bulk imported from the business school ([LBS](http://www.london.edu/)
and [Haas](http://www.haas.berkeley.edu/) ). Given the size of the years, there are ~1000 people I have therefore never
properly spoken to. Quite a thought.

But this has left my address book rather cluttered. And as fast as my [Samsung Galaxy
S3](http://www.samsung.com/uk/consumer/mobile-devices/smartphones/android/GT-I9300MBDBTU) is, it struggles with 2500
contacts. Screen switching is slow, particularly when accessing the 'Contacts' app.

So I decided to have a purge. An automated purge. I wanted to find contacts where:

* I had no phone number for the individual
* I had only one email address for the individual, and that email address was a `london.edu` or `mba.berkeley.edu` address
* They had sent me (not a list) zero emails

Conditions 1 and 2 could be solved by inspecting the contacts alone. The third condition makes this task non-trivial,
because it requires an email search on a contact-by-contact basis.

Building on my recently developed [`signet-rails`](https://github.com/myitcv/signet-rails) I decided to give this a go.
This type of task is not well suited to a web application, but it certainly wouldn't harm to exercise `signet-rails` a
bit more.

Below is the controller (again, a Rails app is really not the place for this kind of utility app) code that achieves
this. Once all the contacts have been found that meet the conditions above, each contact is placed into a group called
'Not Used'. This would allow me to perform once last quick visual check in my browser to ensure I wasn't deleting any
legitimate contacts.

The code itself is not the most efficient but demonstrates a couple of interesting/important features:

* Use of [SASL XOAUTH2](https://developers.google.com/gmail/xoauth2_protocol) authentication with `Net::IMAP` for
  password-less access
* Another example usages of `signet-rails`; we rely heavily on the automatic persistence of OAuth2 credentials here...as
  well as automatic refresh of access tokens
* Use of the [Google Contacts API](https://developers.google.com/google-apps/contacts/v3/) outside of the [Google Data
  APIs SDKs](https://developers.google.com/gdata/)
* Use of [Nokogiri](http://nokogiri.org/) to parse the response from the Google Contacts API
* Updating contacts, again outside of the GData SDKs

## Conclusion

The Google Contacts API is not, in its current form, at all usable. In fact it's horrid. One imagines they have a [new
style API](https://developers.google.com/apis-explorer/#p/) cooking in the background, but for now we are stuck with an
Atom-based monster.

The code is not difficult, but the lack of good documentation for the Google Contacts API specifically made progress
slow. That and the very unhelpful error messages every now and then: "Something went wrong - that's all we know"

Still: mission accomplished. My phone is usable again!

## The code

```ruby
require 'net/imap'
require 'nokogiri'

class XOAUTH2Authenticator
  def process(challenge)
    "user=#{`user}\u0001auth=Bearer #{`access_token}\u0001\u0001"
  end

  def initialize(user, access_token)
    @user = user
    @access_token = access_token
  end
end

Net::IMAP.add_authenticator "XOAUTH2", XOAUTH2Authenticator

class HomeController < ApplicationController
  skip_before_filter :require_login, only: [:index]
  skip_authorization_check :only => [:index]

  def index
    if logged_in?
      auth = Signet::Rails::Factory.create_from_env :google, request.env
      client = Google::APIClient.new
      client.authorization = auth

      auth.refresh!

      # ***************************
      # get contacts - gd:etag will not be returned unless you specify the GData-Version header
      contacts_feed = auth.fetch_protected_resource({
	uri: "https://www.google.com/m8/feeds/contacts/#{current_user.email}/full?max-results=10000",
	headers: {'GData-Version' => '3.0'}
      })
      contacts = Nokogiri::XML(contacts_feed.body.to_s)

      # find 'low use' contacts; 0 phone numbers, email address either `london.edu or `mba.berkeley.edu
      low_use = contacts.xpath("//xmlns:entry[count(gd:phoneNumber) = 0 and count(gd:email) = 1 and (contains(gd:email/`address, 'mba.berkeley.edu') or contains(gd:email/`address, 'london.edu'))]")

      # ***************************
      # setup imap
      imap = Net::IMAP.new('imap.gmail.com', {ssl: true})
      imap.authenticate('XOAUTH2', current_user.email, auth.access_token)
      all_mail = imap.select('[Google Mail]/All Mail')

      # iterate through each low_use contact and find emails from them to me
      for c in low_use do
	# there will only be one email address.... based on the xpath above
	email = c.xpath('gd:email').first['address']
	next if email.nil?
	matches = imap.search(['FROM', email, 'TO', 'me'])

	# if there are no emails from this 'low use' contact...
	if matches.count == 0
	  group = Nokogiri::XML::Node.new 'groupMembershipInfo', contacts

	  # this is a bit bizarre - is this a nokogiri bug? Need to use explicit setter?
	  group.namespace = group.add_namespace('gContact', 'http://schemas.google.com/contact/2008')
	  group['deleted'] = false

	  # this is the group where I want to collect these contacts
	  group['href'] = 'http://www.google.com/m8/feeds/groups/paul%40myitcv.org.uk/base/3fa06f7f88078654'
	  c.add_child(group)

	  # for some reason, the spec suggests these namespaces aren't required, but missing them off causes errors referring to namespace binding
	  c['xmlns:gd'] = 'http://schemas.google.com/g/2005'
	  c['xmlns'] = 'http://www.w3.org/2005/Atom'
	  c['xmlns:gContact'] = 'http://schemas.google.com/contact/2008'

	  # again, bizarre that the ID URL is not the exact URL we should use for updates
	  update_uri = c.xpath('xmlns:id/text()').to_s.sub('/base/','/full/').sub('http:','https:')

	  # this will help ensure we only update the version we were given
	  etag = c.xpath('@gd:etag').to_s

	  # PUT an update; note the special headers...
	  updated_contact = auth.fetch_protected_resource({
	    uri: update_uri,
	    method: :put,
	    body: c.to_s,
	    headers: {
	      'If-Match' => etag,
	      'GData-Version' => '3.0',
	      'Content-type' => 'application/atom+xml',
	  }})
	end
      end
    end
  end
end
```
