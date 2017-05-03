---
date: 2017-05-02
layout: post
title: JSX, CSS and stateGen support in myitcv.io/react
location: London
author: paul
---

[`myitcv.io/react`](https://myitcv.io/react) is a set of [GopherJS](https://github.com/gopherjs/gopherjs) bindings for
Facebook's [React](https://facebook.github.io/react/), a Javascript library for building interactive user interfaces.

This post details the main features in the latest "release": [2017-05-02 - CSS, stateGen and JSX
goodies](https://github.com/myitcv/react/wiki/Changelog#2017-05-02---css-stategen-and-jsx-goodies)

### JSX-like support

JSX is an embeddable XML-like syntax, that effectively allows you to write HTML (for example) in amongst your regular
application code. It came to prominence when support was introduced within the React framework. Here is a simple
example, taken from the React homepage:


```
class HelloMessage extends React.Component {
  render() {
    return <div>Hello {this.props.name}</div>;
  }
}
```

Its popularity widened, and perhaps most notably it is supported as a first-class citizen within the
[TypeScript](https://www.typescriptlang.org/docs/handbook/jsx.html) language: embedding, type checking, and compiling
JSX directly into JavaScript.

With `myitcv.io/react` we are not (currently) in the mood for any Go language changes, so instead we "fake" things via
compile time string constants. This ultimately needs a change within the compiler for proper compile-time support
(tracked in [#64](https://github.com/myitcv/react/issues/64)), so for now we provide a runtime stop-gap solution.

Here's a basic example:

```go
func (a *AppDef) Render() r.Element {
	return r.Div(nil,
		jsx.HTML(`
		<h1>Hello World</h1>

		<p>This is my first GopherJS React App.</p>
		`)...,
	)
}
```

At runtime this component is rendered as if we'd written:

```go
func (a *AppDef) Render() r.Element {
	return r.Div(nil,
		r.H1(nil,
			r.S("Hello World"),
		),
		r.P(nil,
			r.S("This is my first GopherJS React App."),
		),
	)
}
```

Or you could equivalently use `jsx.Markdown`:

```go
func (a *AppDef) Render() r.Element {
	return r.Div(nil,
		jsx.Markdown(`
# Hello World

This is my first GopherJS React App.
	`)...,
	)
}
```

The arguments to the `jsx.*` functions must be compile-time string constants. To enforce this we also provide
[`reactVet`](https://github.com/myitcv/react/wiki/reactVet). Whilst the stop-gap solution remains this also helps to
prevent security problems (non-constant values would open the door to user-provided HTML or Markdown strings).

Clearly this "compile-time string constants"-approach is limited when compared to TypeScript's native support. But it
feels like an appropriate first step for now... Further tooling/compiler support might then follow.

See the [`godoc`](https://godoc.org/myitcv.io/react/jsx) for more details.


### Global state trees via `stateGen`

If you've ever used ClojureScript's [Reagent](https://github.com/reagent-project/reagent) you may have come across
`atom`. Atoms provide a way to manage shared, synchronous, independent state. Reagent components can share state using
`atom`'s.

With `myitcv.io/react` we achieve a similar result via
[`stateGen`](https://github.com/myitcv/react/tree/master/cmd/stateGen). `stateGen` translates a succinct Go-based
template into a typed state tree. Here is an example template (taken from the [global state
example](https://github.com/myitcv/react/blob/master/examples/sites/globalstate/state/state.go)):

```go
package state

import "myitcv.io/react/examples/sites/globalstate/model"

//go:generate stateGen

var State = NewRoot()

var root _Node_App

type _Node_App struct {
	CurrentPerson *model.Person
	Root          *_Node_Data
}

type _Node_Data struct {
	People *model.People
}
```

The resulting state tree is best viewed via the
[`godoc`'s](https://godoc.org/myitcv.io/react/examples/sites/globalstate/state). It allows components to synchronously
mutate and share state with other components.

_I tend to enforce that the leaves of a state tree only contain [immutable](https://myitcv.io/immutable) values/data
structures. This makes reasoning about state transitions much easier and ensures that components cannot modify data
"underneath" another that might share a reference to the same value/data structure._

The [`PersonChooser`](https://github.com/myitcv/react/blob/master/examples/sites/globalstate/person_chooser.go)
component that is part of the [global state example](http://blog.myitcv.io/gopherjs_examples_sites/globalstate/) shows
how the state tree is used. A component can either reference the global variable that represents the singleton instance
of the state tree, or it can reference a node/leaf from the tree. If the referencing of a node/leaf is achieved via
interfaces, then the component can be made reusable (i.e.  instances of that component can be passed different
nodes/leaves from the state tree via props).

The `PersonChooser` component is _not_ reusable despite it's props being interface-based:

```go
type PersonChooserProps struct {
	PersonState
}

type PersonState interface {
	Get() *model.Person
	Set(p *model.Person)
	Subscribe(cb func()) *state.Sub
}
```

Why? The `Render` method directly reference the singleton state instance:

```go
func (p *PersonChooserDef) Render() r.Element {

	ppl := sortPeopleKeysByName(state.State.Root().People().Get())

        //...
```

Of course this could easily be fixed by passing in a `*model.People` value via the props.

This is very much a first-cut of `stateGen` - feedback/questions/questions greatly appreciated via [Github
issues](https://github.com/myitcv/react/issues).

### Events are now interface-based

This change is most easily understood by looking at the props type for, say, a `<button>`:

```go
type ButtonProps struct {
	// ...

	OnChange
	OnClick

	// ...
}
```

`OnClick` (and `OnChange`) are both interface types:

```go
type OnClick interface {
	Event

	OnClick(e *SyntheticMouseEvent)
}
```

This then gets used in the following way (taken from the [immutable TODO app
example](https://github.com/myitcv/react/blob/f0cfa34cef9665b44e23b00c4e72b9f150a3f1cf/examples/immtodoapp/todo_app.go)):

```go
func (t *MyComp) Render() r.Element {
	return r.Button(&r.ButtonProps{
		Type:      "submit",
		ClassName: "btn btn-default",
		OnClick:   click{t},
	})
}


type click struct{ t *MyComp }

func (c click) OnClick(se *r.SyntheticMouseEvent) {
	ns := c.t.State()

	ns.items = ns.items.Append(new(item).setName(ns.currItem))
	ns.currItem = ""

	c.t.SetState(ns)

	se.PreventDefault()
}

```

Why move away from `func` types on props and state? Slice, map, and function values are not comparable ([per the
spec](https://golang.org/ref/spec#Comparison_operators)). Using interface values comes at a marginal (if any) cost to
the author/reader. But critically, having comparable props and state, there is a huge benefit in terms of reasoning
about component updates/re-rendering behaviour.

### Feedback/questions/concerns


Feedback, questions, concerns very much appreciated via [Github issues](https://github.com/myitcv/react/issues) or the
[Gophers `#gopherjs` Slack channel](slack://gophers.slack.com/messages/#gopherjs).
