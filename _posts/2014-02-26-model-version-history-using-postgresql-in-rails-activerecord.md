---
date: 2014-02-26
layout: post
title: Model version history using PostgreSQL in Rails ActiveRecord
location: London
author: paul
tags:
- aws
- rds
- postgresql
- rails
- activerecord
---

Building on [an earlier post about row-level version control with
PostgreSQL](/2014/02/25/row-level-version-control-with-postgresql.html), this article looks to show how to use
version history within [Rails] models or, more generically, any Ruby application that uses [ActiveRecord] models.

For the sake of ease, the steps below outline how to create a basic Rails application, with a single model (the old
fruit example again) that supports version history. This basic model will also support:

* UUID id column - this is a fairly common requirement for web apps
* Correct primary key constraints - ActiveRecord doesn't do a great job of getting these right for more custom models
* [Optimistic locking](http://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html) - because we want our
users to be sure their updates are applied to the versions they were editing

What follows has been tested against the following software and corresponding versions:

|Package|Version|
|-------|-------|
|Ruby|`ruby 2.1.1p76 (2014-02-24 revision 45161) [x86_64-linux]`|
|Rails|`Rails 4.0.3`|
|PostgreSQL on AWS RDS|`PostgreSQL 9.3.2`|
|PostgreSQL CLI|`psql (PostgreSQL) 9.3.3`|

What follows also assumes you have a usable [AWS PostgreSQL RDS] instance.

## Preparation

Let's create ourselves a basic Rails app:

```bash
$ rails new --no-rc version_history_test && cd $_
```

We will need to add the `pg` gem to our `Gemfile`:

```ruby
# Gemfile

source 'https://rubygems.org'
gem 'rails', '4.0.3'
gem 'sqlite3'
gem 'sass-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'turbolinks'
gem 'jbuilder', '~> 1.2'
group :doc do
  gem 'sdoc', require: false
end

# add pg gem
gem 'pg'
```

A quick run of `bundle install` will ensure this is in place.

Before we go any further, let's reconfigure our development database to point to our AWS PostgreSQL instance (substitute
your details where appropriate):

```yaml
# config/database.yml

development:
  adapter: postgresql
  database: mydb
  username: master
  password: XXXXXXXXXXXXX
  host: mypostgresql.YYYYYYYYYYY.eu-west-1.rds.amazonaws.com
  pool: 5
  timeout: 5000

# test and production sections omitted
```

We now need to ensure that the
[`time_travel_trigger`](https://gist.github.com/myitcv/9212407#file-time_travel_trigger-sql) is correctly installed on
our new PostgreSQL instance. We will do this by means of a migration. First create an empty migration:

```bash
$ rails g migration install_time_travel_function
      invoke  active_record
      create    db/migrate/20140226220507_install_time_travel_function.rb
```

Now to edit the migration (which is `db/migrate/20140226220507_install_time_travel_function.rb` in my case):

```ruby
class InstallTimeTravelFunction < ActiveRecord::Migration
  def change

    # we need both extensions enabled
    enable_extension "plpgsql"
    enable_extension "uuid-ossp"

    execute <<-EOD

    -- ** INSERT LATEST VERSION OF TIME_TRAVEL_TRIGGER.SQL HERE FROM:
    --    https://gist.github.com/myitcv/9212407

    EOD
  end
end
```

The contents of `time_travel_trigger` have been omitted to save space; simply drop in where indicated. Then run `rake
db:migrate` to execute the migration (some lines of output omitted):

```bash
$ rake db:migrate
==  InstallTimeTravelFunction: migrating ======================================
-- enable_extension("plpgsql")
   -> 0.1064s
-- enable_extension("uuid-ossp")
   -> 0.1338s -- execute("\nCREATE OR REPLACE FUNCTION ...

==  InstallTimeTravelFunction: migrated (0.3313s) =============================
```

We are now in a position to be able to create our model.

## Creating our fruit model

To kick start the model creation we use `rails generate` (again the output from the command is shown for clarity's
sake):

```bash
$ rails g model fruit id:uuid name:string valid_from:datetime valid_to:datetime lock_version:integer
      invoke  active_record
      create    db/migrate/20140226220508_create_fruits.rb
      create    app/models/fruit.rb
      invoke    test_unit
      create      test/models/fruit_test.rb
      create      test/fixtures/fruits.yml
```

There are various aspects of what we are doing that are not supported by ActiveRecord (Arel). So we need to make some
changes to the migration file that has been created (which is `db/migrate/20140226220508_create_fruits.rb` in my case).
It should look like this:

```ruby
# db/migrate/20140226220508_create_fruits.rb

class CreateFruits < ActiveRecord::Migration
  def change

    # don't create default id; we want to create id:uuid
    create_table :fruits, id: false, force: true do |t|

      # use uuid_generate_v4 for random uuids
      t.uuid     :id, default: "uuid_generate_v4()", null: false
      t.text     :name

      # our time travel columns
      t.datetime :valid_from, null: false
      t.datetime :valid_to, null: false

      # lock_version as defined by http://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html
      t.integer  :lock_version, default: 0, null: false

      #
      # ** NO TIMESTAMPS **
      #
    end

    # for some reason create_table doesn't get this right....
    change_column  :fruits, :id, :uuid, null: false

    # create the primary key constraint
    execute "alter table fruits add primary key (id, lock_version)"

    # create the triggers to call the timetravel-esque functions
    execute <<-EOD
      CREATE TRIGGER fruits_before
      BEFORE INSERT OR UPDATE OR DELETE ON fruits
          FOR EACH ROW EXECUTE PROCEDURE process_timetravel_before();

      CREATE TRIGGER fruits_after
      AFTER UPDATE OR DELETE ON fruits
          FOR EACH ROW EXECUTE PROCEDURE process_timetravel_after();
    EOD
  end
end
```

Again, `rake db:migrate` should run without errors:

```bash
$ rake db:migrate
==  CreateFruits: migrating ===================================================
-- create_table(:fruits, {:id=>false, :force=>true})
   -> 0.0852s
-- change_column(:fruits, :id, :uuid, {:null=>false})
   -> 0.0636s
-- execute("alter table fruits add primary key (id, lock_version)")
   -> 0.0475s
-- execute("      CREATE TRIGGER fruits_before...

==  CreateFruits: migrated (0.2351s) ==========================================
```

We are almost done. Having overridden the default primary key, we need to tell ActiveRecord what the new primary key is
by editing the model class:

```ruby
# app/models/fruit.rb

class Fruit < ActiveRecord::Base

  # we have overridden the default primary_key
  # even though lock_version is strictly part of the
  # primary key, its use happens behind the scenes
  self.primary_key = :id

  # by default, when searching and finding bits of fruit
  # we want the latest version
  default_scope { where(valid_to: 'infinity').reorder('') }
end
```

And that's our model created. Relatively painless. Let's see it in action.

## Creating some fruit

The simplest way to test out our model is via the Rails console which is started via:

```bash
$ rails console
Loading development environment (Rails 4.0.3)
irb(main):001:0>
```

Let us first create an apple:


```ruby
irb(main):001:0> f = Fruit.create name: 'apple'
   (28.5ms)  BEGIN
  SQL (94.0ms)  INSERT INTO "fruits" ("name", "valid_to") VALUES ($1, $2) RETURNING "id"  [["name", "apple"], ["valid_to", nil]]
   (33.9ms)  COMMIT
=> #<Fruit id: "2222b79d-d422-4f2b-a23a-9d2148398e17", name: "apple", valid_from: nil, valid_to: nil, lock_version: 0>
```

A quick look in the database (using the PostgreSQL CLI) will show the corresponding row:

```sql
mydb=> select * from fruits order by lock_version;
                  id                  | name  |         valid_from         | valid_to | lock_version
--------------------------------------+-------+----------------------------+----------+--------------
 2222b79d-d422-4f2b-a23a-9d2148398e17 | apple | 2014-02-26 20:36:48.885796 | infinity |            0
```

Back in the Rails console, let's change our apple to a pear:

```ruby
irb(main):002:0> f.name = 'pear'
=> "pear"
irb(main):003:0> f.save
   (31.3ms)  BEGIN
   (35.0ms)  UPDATE "fruits" SET "name" = 'pear', "lock_version" = 1 WHERE ("fruits"."id" = '2222b79d-d422-4f2b-a23a-9d2148398e17' AND "fruits"."lock_version" = 0)
   (33.1ms)  COMMIT
=> true
```

See how the use of optimistic locking ensures that the update is applied to the latest version (thereby obviating
the need for the restriction `valid_to = 'infinity'`). Again, let's check in on the database to see what's happened:

```sql
mydb=> select * from fruits order by lock_version;
                  id                  | name  |         valid_from         |          valid_to          | lock_version
--------------------------------------+-------+----------------------------+----------------------------+--------------
 2222b79d-d422-4f2b-a23a-9d2148398e17 | apple | 2014-02-26 20:36:48.885796 | 2014-02-26 20:38:19.228829 |            0
 2222b79d-d422-4f2b-a23a-9d2148398e17 | pear  | 2014-02-26 20:38:19.228829 | infinity                   |            1
```

Just as we expected, a new version has been created.

But we're finished with this pear now. Time to destroy it (again, from the Rails console):

```ruby
irb(main):004:0> f.destroy
   (57.2ms)  BEGIN
  SQL (60.1ms)  DELETE FROM "fruits" WHERE "fruits"."id" = $1 AND "fruits"."lock_version" = $2  [["id", "2222b79d-d422-4f2b-a23a-9d2148398e17"], ["lock_version", 1]]
   (36.7ms)  COMMIT
=> #<Fruit id: "2222b79d-d422-4f2b-a23a-9d2148398e17", name: "pear", valid_from: nil, valid_to: nil, lock_version: 1>
```

Again, the optimistic locking support in ActiveRecord is helping ensure we delete only the latest version. If we glance
in the database, we should expect to see just the `valid_to` be updated from `infinity` to the time of the delete:

```sql
mydb=> select * from fruits order by lock_version;
                  id                  | name  |         valid_from         |          valid_to          | lock_version
--------------------------------------+-------+----------------------------+----------------------------+--------------
 2222b79d-d422-4f2b-a23a-9d2148398e17 | apple | 2014-02-26 20:36:48.885796 | 2014-02-26 20:38:19.228829 |            0
 2222b79d-d422-4f2b-a23a-9d2148398e17 | pear  | 2014-02-26 20:38:19.228829 | 2014-02-26 20:40:55.016373 |            1
```

Excellent.

## Version-based queries

Using `lock_version` we can clearly find previous versions of a record. Here
we load version 0 of our piece of fruit, which was an apple at the time:

```ruby
irb(main):005:0> f = Fruit.unscoped.find_by(id: '2222b79d-d422-4f2b-a23a-9d2148398e17', lock_version: 0)
  Fruit Load (37.1ms)  SELECT "fruits".* FROM "fruits" WHERE "fruits"."id" = '2222b79d-d422-4f2b-a23a-9d2148398e17' AND "fruits"."lock_version" = 0 LIMIT 1
=> #<Fruit id: "2222b79d-d422-4f2b-a23a-9d2148398e17", name: "apple", valid_from: "2014-02-26 20:36:48", valid_to: "2014-02-26 20:38:19", lock_version: 0>
irb(main):006:0> f.name
=> "apple"
```

Notice the use of `unscoped` to remove the default scope.

## Time-based queries

Because of our primary key constraint and strictly contiguous `valid_from` and
`valid_to` time blocks, we can even do sensible looking time-based queries:

```ruby
irb(main):007:0> date = DateTime.parse '2014-02-26 20:37'
=> Wed, 26 Feb 2014 20:37:00 +0000
irb(main):008:0> Fruit.unscoped.where('valid_from < ? AND ? < valid_to', date, date).find('2222b79d-d422-4f2b-a23a-9d2148398e17')
  Fruit Load (62.5ms)  SELECT "fruits".* FROM "fruits" WHERE (valid_from < '2014-02-26 20:37:00.000000' AND '2014-02-26 20:37:00.000000' < valid_to) AND "fruits"."id" = $1 LIMIT 1  [["id", "2222b79d-d422-4f2b-a23a-9d2148398e17"]]
=> #<Fruit id: "2222b79d-d422-4f2b-a23a-9d2148398e17", name: "apple", valid_from: "2014-02-26 20:36:48", valid_to: "2014-02-26 20:38:19", lock_version: 0>
irb(main):009:0> f.name
=> "apple"
```

Again, note the use of `unscoped`. But also the use of `find` which works by virtue of the preceding `where` clauses.

## A note on optimistic locking

Earlier we set out optimistic locking as one of the additional goals of this exercise. But there are some important
benefits that ActiveRecord's optimistic locking brings to our version control implementation.

Firstly, it makes the definition of our primary key very clean. The pair `[id, lock_version]` is much more
understandable than a primary key that involves `valid_from` and/or `valid_to`.

The second benefit, as we have seen, is that it ensures ActiveRecord only updates/deletes the latest version (the
[function behind the trigger](https://gist.github.com/myitcv/9212407#file-time_travel_trigger-sql) also ensures this,
but using `lock_version` is much cleaner), thereby obviating the need for us to restrict by `valid_to = 'infinity'` on
all updates (the default scope helps on reads, but not writes).

## Source code

The complete source code (minus passwords) is available [on
GitHub](https://github.com/myitcv/postgres_version_history_demo) as usual.

## Conclusion

This is a simple(ish) method of achieving version history on Rails (ActiveRecord) models with PostgreSQL. There are
alternative methods out there, but this time-based approach allows for huge power when querying (not least because it
works with joins too).

But it is a first cut. So any feedback greatly appreciated.

[Rails]: http://rubyonrails.org/
[ActiveRecord]: https://rubygems.org/gems/activerecord
[AWS PostgreSQL RDS]: http://aws.amazon.com/rds/postgresql/
