---
layout: post
title: omniauth + Google OAuth2 on Rails
location: San Francisco
author: paul
tags:
- coding
- ruby
- rails
- oauth2
---

**Update 2013-03-10:** modified to use [figaro](https://github.com/laserlemon/figaro) instead of rather half-baked
`parseconfig` approach.<br/>
**Update 2013-03-24:** modified to use `ActiveRecord` sessions and `first_or_initialize` for user creation (moving the
logic from the model to the controller)<br/>
**Update 2013-06-20:** I have written a [follow-up
post](/2013/06/20/using-google-apis-in-rails-apps-with-oauth-2.0.html) which provides a better example of OAuth2,
persistance of OAuth credentials and using those credentials with Google APIs

<hr/>

All of the code for the following example is [on GitHub](https://github.com/myitcv/omniauth-google-oauth2-example) .
However for the sake of readability I have left out the init of a git repository in the description that follows...
clearly this is an important step

First fire up a terminal and change to your development directory:

```bash
rails new omniauth-google-oauth2-example
cd omniauth-google-oauth2-example
```

You will at this point be in the directory Rails just created.

Now edit the `Gemfile` to include the following [Haml](http://haml.info/) and
[figaro](https://github.com/laserlemon/figaro) support:

```ruby
# /Gemfile
# ...

gem 'haml'
gem 'haml-rails'
gem 'figaro'

# ...
```

Let's now ensure the requisite gems are installed:

```bash
bundle install
```

Now let's ensure the figaro setup is in place:

```bash
rails generate figaro:install
```

Time to tidy up a couple of files that we no longer need (for this simple example at least). Back to the terminal:

```bash
rm app/views/layouts/application.html.erb
rm public/index.html
```

Now to generate our first controller:

```bash
rails generate controller home index
```

Now edit the routes to set the root path:

```ruby
# /config/routes.rb

OmniauthGoogleOauth2Example::Application.routes.draw do
  get "home/index"
  root :to => 'home#index'
end
```

We should at this point be able to fire up the `rails server` and see the default view we just created:

```bash
rails server
```

If your configure is like mine, head to [http://localhost:3000](http://localhost:3000) to see the results. It should
look something like:

<hr/>
![](/images/2013-02-19-first-run-of-rails.png)
<hr/>

So now we have a working Rails setup that uses Haml as the template language. Before we go too far, let's setup the
session handling and user model:

```bash
rails generate session_migration
rails generate controller sessions
rails generate model user provider:string \
  uid:string \
  name:string \
  refresh_token:string \
  access_token:string \
  expires:timestamp
rake db:migrate
```

Let's configure rails to use the ActiveRecord session handling:

```ruby
# config/initializers/session_store.rb

# replace the contents of the entire file
OmniauthGoogleOauth2Example::Application.config.session_store :active_record_store
```

We will add the routes to the session handling later (it will actually be a callback from our Google auth provider). So
for now let's fill out the session controller and the user model:

```ruby
# /app/controllers/sessions_controller.rb

class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    user = User.where(:provider => auth["provider"], :uid => auth["uid"]).first_or_initialize(
      :refresh_token => auth["credentials"]["refresh_token"],
      :access_token => auth["credentials"]["token"],
      :expires => auth["credentials"]["expires_at"],
      :name => auth["info"]["name"],
    )
    url = session[:return_to] || root_path
    session[:return_to] = nil
    url = root_path if url.eql?('/logout')

    if user.save
      session[:user_id] = user.id
      notice = "Signed in!"
      logger.debug "URL to redirect to: #{url}"
      redirect_to url, :notice => notice
    else
      raise "Failed to login"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, :notice => "Signed out!"
  end
end
```

```ruby
# /app/models/user.rb

class User < ActiveRecord::Base
  attr_accessible :name, :provider, :uid, :refresh_token, :access_token, :expires

  validates_uniqueness_of :uid, :scope => :provider
end
```

OK, let's include the Google omniauth piece now. First, back to edit the `Gemfile` to include:

```ruby
# /Gemfile
# ...

gem 'omniauth-google-oauth2'

# ...
```

Again, let's ensure the gems are installed:

```bash
bundle install
```

Now you need to [head over to the Google apis console](https://code.google.com/apis/console/) and create an API Project.
[Create a project](https://developers.google.com/console/help/#creatingdeletingprojects) then you need to [generate and
OAuth 2.0 client ID](https://developers.google.com/console/help/#generatingoauth2) :

<hr/>
![](/images/2013-02-19-google-oauth2.png)
<hr/>

The settings for this basic test are:

|Setting                |Value                                                  |
|-----------------------|-------------------------------------------------------|
|Product name:          |www.myitcv.org.uk                                      |
|Application type:      |Web Application                                        |
|Your site or hostname: |``http://localhost:3000/auth/google_login/callback`    |

You should now be presented with a page that includes a *Client ID* and *Client secret*. We need to populate these in
our `config/application.yml` file:

```yaml
# config/application.yml

OAUTH_CLIENT_ID: "<CLIENT_ID>"
OAUTH_CLIENT_SECRET: "<CLIENT_SECRET>"
APPLICATION_CONFIG_SECRET_TOKEN: "<A LONG SECRET>"
```

(In the commited files I have also include a 'secret' for the application's secret token. Check out
[config/initializers/secret_token.rb](https://github.com/myitcv/omniauth-google-oauth2-example/blob/master/config/initializers/secret_token.rb)
for the code)

Now create the following file:

```ruby
# /config/initializers/omniauth.rb

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV['OAUTH_CLIENT_ID'],
    ENV['OAUTH_CLIENT_SECRET'],
    {name: "google_login", approval_prompt: ''}
end
```

Couple of things to notice here. Firstly, we have named this provider; this is good practice in case you want to add
other Google-based authorisation providers to your site (for example there is a sub section of your site that requires
access to a user's calendar).

Secondly, *and this really caught me out*, we set the <code>approval_prompt</code> to <code>''</code>. This is not
particularly well document anywhere that I could find. Basically, if you don't set this to blank, the user will be
prompted to permission your web application every time they access your site. Why? Because the default (unless you
override to blank) is a setting of <code>'force'</code>. This took me far too long to work out.

Now lets setup the routes for omniauth:

```ruby
# /config/routes.rb

OmniauthGoogleOauth2Example::Application.routes.draw do
  get "home/index"
  root :to => 'home#index'
  match "/auth/google_login/callback" => "sessions#create"
  match "/signout" => "sessions#destroy", :as => :signout
end
```

Getting there. Now let's put in place an improved front page that presents some simple links allowing us to login/logout
etc.

```ruby
# /app/views/home/index.html.haml

%h1 Home
- if flash[:notice]
  %h2 *** #{flash[:notice]} ***
- if current_user
  %p Welcome #{current_user.name}!
  %p
    = link_to "Sign Out", signout_path
- else
  %p
    = link_to "Sign in with Google google_login", "/auth/google_login"
    = link_to "Auth with Google google_auth", "/auth/google_auth"
```

You will see we are referencing a helper function here that we need to define:

```ruby
# /app/controllers/application_controller.rb

class ApplicationController < ActionController::Base
  protect_from_forgery

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
```


