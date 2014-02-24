---
layout: post
title: Processing semi-unstructured strings
location: San Francisco
author: paul
tags:
- coding
- ruby
---

I found myself dealing with a number of strings that contained colon delimited @lval:rval@ pairs. For example:

```ruby
string = "Fruit:orangeSize:largeQuantity:5Fruit:Apple"
```

Here the lvals are clearly:

```ruby
lvals = %w(Fruit: Size: Quantity:)
rvals = %w(orange large 5 Apple)
```

The further complication is that each lval is optional in any given string and the order is undefined.

So under the lval superset of:

```ruby
%w(Fruit: Size: Quantity: Fresh:)
```

the following strings are valid:

```ruby
string1 = "Fruit:orangeSize:largeQuantity:5Fruit:Apple"
string2 = "Fruit:orangeSize:largeQuantity:5Fruit:AppleFresh:today"
```

The challenge: to efficiently "collect" the rvals for all the lvals. So for each of the strings above we would expect:

```ruby
result1 = {"Fruit:"=>["orange", "Apple"], "Size:"=>["large"], "Quantity:"=>["5"], "Fresh:"=>[]}
result2 = {"Fruit:"=>["orange", "Apple"], "Size:"=>["large"], "Quantity:"=>["5"], "Fresh:"=>["today"]}
```

My solution (probably not the most efficient) was slightly more involved that I had thought it would be:

<script src="https://gist.github.com/myitcv/5062274.js"></script>
