---
date: 2014-02-25
layout: post
title: Row-level version control with PostgreSQL on AWS
location: London
author: paul
tags:
- aws
- rds
- postgresql
---

Time Travel appears to have been a little known feature of [PostgreSQL] that [fell out of favour as of version
`6.2`](http://www.postgresql.org/docs/6.3/static/c0503.htm). This feature effectively provided row-level version history
- a paper trail of all your changes to data in a table - something useful when it comes to auditing, providing version
history to users etc.  This post covers how to achieve Time Travel-esque behaviour using [AWS' PostgreSQL RDS] via
triggers.

## Background

Time Travel achieves version history by means of two columns (which could incidentally be called anything) that track
when the row was valid from, and when it was valid to. By means of an example (you can ignore the details for now, we
come to them later), let us first create a piece of fruit:

```sql
myitcv=# insert into fruits (name) values ('apple');
myitcv=# select * from fruits;
 id | name  |         valid_from         | valid_to
----+-------+----------------------------+----------
  1 | apple | 2014-02-26 11:40:17.014514 | infinity
```

Creating a new record inserts a new row into our table. `valid_from = now()` corresponds to the creation time. Notice
the `valid_to = infinity` - this tells us that the row is current.

If we then change the name of the piece of fruit (notice we use the restriction `valid_to = infinity` to refer to the
latest version):

```sql
myitcv=# update fruits set name = 'pear' where id = 1 and valid_to = 'infinity';
myitcv=# select * from fruits;
 id | name  |         valid_from         |          valid_to
----+-------+----------------------------+----------------------------
  1 | apple | 2014-02-26 11:40:17.014514 | 2014-02-26 11:40:17.015796
  1 | pear  | 2014-02-26 11:40:17.015796 | infinity
```

The update has been translated into two changes:

1. Update `valid_to` on the now old version to `now()`
2. Insert a new row to represent the new version, following the same logic for `valid_from` as for insert

And then finally delete the piece of fruit; we don't need it any more:

```sql
myitcv=# delete from fruits where id = 1 and valid_to = 'infinity';
myitcv=# select * from fruits;
 id | name  |         valid_from         |          valid_to
----+-------+----------------------------+----------------------------
  1 | apple | 2014-02-26 11:40:17.014514 | 2014-02-26 11:40:17.015796
  1 | pear  | 2014-02-26 11:40:17.015796 | 2014-02-26 11:40:17.018864
```

Notice the row itself is not deleted, rather the `valid_to` date is simply updated from `infinity -> now()`. This is in
effect a soft delete.

With appropriate indexes and restrictions on key constraints, this can in effect give you a version history, or paper
trail if you will, of changes to rows in your table. Nothing gets deleted; we append to the table any changes, including
deletes. Good for auditing... Good for all manner of things.

## How do I use Time Travel?

It depends on where you are using PostgreSQL.

### Recent version of PostgreSQL under your control

Time Travel lives on in later versions of PostgreSQL via the [spi contrib
module](http://www.postgresql.org/docs/9.3/static/contrib-spi.html). If you are in control of your PostgreSQL
installation, you can simply install the extension:

```sql
myitcv=# create extension timetravel;
```

then follow an example given [in the PostgreSQL
source](https://github.com/postgres/postgres/blob/master/contrib/spi/timetravel.example) to get up and running and start
travelling back through time immediately. Eat your heart out, Marty McFly.

At this point you could stop reading this article because you have a working time machine! What follows might however be
of interest: it is a trigger-based equivalent to the spi module that (importantly) brings the `timetravel` behaviour to
PostgreSQL on AWS.

### PostgreSQL on AWS

If you are using [AWS' PostgreSQL RDS] you will be disappointed to learn that [`timetravel` is not a supported
extension](https://forums.aws.amazon.com/thread.jspa?threadID=146661), as of 2014-02-25 at least.

As the [legacy `v6.3` documentation points out](http://www.postgresql.org/docs/6.3/static/c0503.htm) however,
`timetravel`-like behaviour can be achieved using triggers. The goal of the remainder of this post, as mentioned
earlier, is to try and achieve just that.

What follows assumes:

* The you are familiar with [PostgreSQL]
* That you have a PostgreSQL instance running on AWS (my tests were against a `v9.3.2` instance in `eu-west`)
* You can connect to that instance using the PostgreSQL CLI or some GUI tool (to execute arbitrary SQL)

## Installing the main function (trigger)

To get up and running, you will need to execute the following SQL to create the main function that simulates `timetravel`:

<div style="font-size:12px">
<script src="https://gist.github.com/myitcv/9212407.js"></script>
</div>

The code itself is commented to give some motivation behind certain decisions. But the one point worth making regards
deletes.

A delete could simply be achieved by intercepting a user request to delete and translating that to update the `valid_to
= now()` on the corresponding row. We would therefore silently ignore the request to delete something. However,
the effect of this is to return that 0 rows were affected by the delete. Client libraries using our table might well have problems
with this ([ActiveRecrod with optimistic
locking](http://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html) does for example). Hence we have to go
to the effort of inserting a new row to represent the old version (much like we do for an update) and then allow the
original delete to continue.

## The trigger in action: fruit

By itself, the aforementioned function is useless. So how do we use it? The following SQL gives just such an example:

```sql
DROP TABLE IF EXISTS fruits;

CREATE TABLE fruits (
  id SERIAL NOT NULL,
  name TEXT,
  valid_from TIMESTAMP NOT NULL,
  valid_to TIMESTAMP NOT NULL
);

DROP TRIGGER IF EXISTS fruits_before ON fruits;
CREATE TRIGGER fruits_before
BEFORE INSERT OR UPDATE OR DELETE ON fruits
  FOR EACH ROW EXECUTE PROCEDURE process_timetravel_before();
```

Again, execute this SQL to create the tables and triggers, at which point you should be in a position to run the
SQL found earlier in this post where we created, updated and deleted an apple (pear).

## Known limitations/problems

Feedback, corrections, suggestions etc. would be greatly appreciated. Indeed, please let me know if something should be
added to this list:

* The main function assumes that the table columns that provide `valid_from` and `valid_to` are called just that.
`timetravel` provided support for providing alternative columns (e.g. `starting` and `ending`); our version is limited
in that respect
* This whole process only safely works within a transaction; our version does not check that it is called within the
context of a transaction

## References

In writing this trigger-based alternative to `timetravel`, I've relied heavily on:

* [PostgreSQL's trigger documentation](http://www.postgresql.org/docs/9.3/static/plpgsql-trigger.html)
* [PostgreSQL's explicit locking documentation](http://www.postgresql.org/docs/9.3/static/explicit-locking.html)
* [Documentation on PL/pgSQL - SQL Procedural Language](http://www.postgresql.org/docs/9.3/static/plpgsql.html)
* Various posts by [Pavel Stěhule] including [this
  one](http://www.postgresql.org/message-id/CAEEEPmxMSgijhG+CdY=hFUZQqZb21697kq9f5dKmAObOAmZLEQ@mail.gmail.com)
* An important note about [executing dynamic
  commands](http://www.postgresql.org/docs/9.3/static/plpgsql-statements.html#PLPGSQL-STATEMENTS-EXECUTING-DYN)

Thanks to the many contributors to PostgreSQL and its community for what is a great DB.

[PostgreSQL]: http://www.postgresql.org/
[AWS' PostgreSQL RDS]: http://aws.amazon.com/rds/postgresql/
[Pavel Stěhule]: http://okbob.blogspot.co.uk/
