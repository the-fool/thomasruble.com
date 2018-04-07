+++
date = "2017-04-02T21:24:05-05:00"
title = "don't use angular's router"
description = "Wrapping our Angular router code in an ngrx/effects module "
tags = ["effects", "ngrx", "angular"]
keywords = ["angular", "ngrx", "redux", "ngrx/effects", "spa"]
+++

# Abstract

*This little polemic assumes that you have a working knowledge of [ngrx/effects](https://github.com/ngrx/effects), and already embrace the Redux the lifestyle.   It just offers a neat `ngrx` pattern that improves app happiness.*

Don't use Angular's built-in router.  At least, do not use it directly. 

Let's say you have a zoo app, and you want to route to a detail view of the 77th weasel.  The typical way to do this is to call `router.navigate(['zoo', 'weasels', 77])` somewhere in your controller.   This type of imperative programming is bad for 3 reasons:

1. Changing routes like this is an unmanaged side-effect.
2. Visiting the 77th weasel requires knowing the magical list of string constants -- `['zoo', 'weasels', id]` -- one change to your route config and you have to track down all these magic strings and change them to fit to the new scheme.
3. This command is floating out in the wide-open -- ie, it is not safely chained to a functional pipeline.

We can fix all this with a simple pattern: a **route effect manager**.  Instead of calling route changes directly with Angular's router, we can use `ngrx/store` to dispatch route change messages.  Thes messages will be nice, DRY, and bearing semantically friendly names.  _Por ejemplo_:

```typescript
class GotoWeaselDetailMessage {
  readonly type = 'WEASEL_DETAIL';
  constructor(public payload: number) {}
}

. . . .

const msg = new GotoWeaselDetailMessage(77);
store.dispatch(msg);
```

That is what we do in our component controller.  *The controller does not need to know anything about the implementation of our route change strategy*.  The route changes themselves, and all the logic they entail, will be taken care of by a bunch of functions registered with `ngrx/effect`.  These will make up our **route effect manager**:

```
import { go } from '@ngrx/router-store';

 . . . 
 
 @Effect() gotoWeaselDetail = this.actions$
     .ofType('WEASEL_DETAIL')
     .map(msg => msg.payload)
     .map(id => go(['zoo', 'weasel', id]));
```

We'll break down the details with complete code below.  Suffice it to say that we define the *implementation* of detailed weasel routes *once*, and everywhere else in the app we use our store's dispatcher as a stable *interface* for invoking these side-effects.  We get all the benefits of Redux and managed-effects, plus extremely DRY code -- and this because we abstain from using Angular's router!


# What's the big deal?

So long as code is correct, there are 2 other things that matter: efficiency and maintainability.  Give a developer 10 correct implementations of a program, what else is there to appraise them by besides speed and elegance?  The **routing manager** pattern is meant to improve code maintainability.

Angular provides a router out of the box.  The way it works is that any part of your codebase is free to invoke a route-change by calling a method with list of strings representing the desired URL.

Like we said above, this ain't such a great way to do things.

  First, freely giving your code the power to initiate side-effects is asking for trouble.  A better way to handle side-effects is to place them inside an `ngrx/effect` manager.  This lets us keep track of them, and know the conditions under which they can happen.  We can also monitor every move our app makes through the excellent `redux-devtools` (hooked up thanks to `ngrx/store-devtools`).

Second, _URL strings are an **implementation detail** of a **semantically** meaningful view_.  That is, we should be able to refer to our different views by meaningful names -- _not_ the URL string.  We should be free to change the string patterns in our URL scheme (or get rid of URL-based nav altogether!) and still have the same semantics with our app's route code.  Right?!  Haven't we all run into the problem where we decide to change our route-scheme, and then needed to hunt down and destroy dozens of incorrect `href=` strings  . . . 

Lastly, if we bring in route changes under the big tent of our `ngrx/store` message dispatcher, then we are that much closer to designing our app with a single unified internal API.  When you want to do something in your app, just dispatch a message to your store.  Embrace the opportunity for unity.

# Code example

The [@ngrx team](https://github.com/ngrx) have a collection of wrappers around common APIs and libraries.  One such wrapper is for Angular's router: the [router-store](https://github.com/ngrx/router-store).  This library exposes a variety of message constructors, the most straight-forward of which is the `go()` message constructor.  The arguments to `go()` follow the [definition](https://angular.io/docs/ts/latest/api/router/index/Router-class.html) of Angular's `router.navigate()` method very closely.  For the above route to the 77th weasel, we would construct a message like so:

```typescript
import { go } from '@ngrx/router-store';

const msg = go(['zoo', 'weasel', 77]);
```

Once we dispatch that message, the `router-store` will pick it up and make an internal call to Angular's router.  Admittedly, the wrapping here is quite thin, and the benefits we get from using the `ngrx/router-store` have mostly to do with gearing our route info into our other redux-esque devtools and instrumentation.

The important point at stake is that we _collect all our route implementations inside of **managed effects pipelines**._

For our zoo app, a routing effect manager could resemble the following:

```typescript
import { Injectable } from '@angular/core';
import { go } from '@ngrx/router-store';
import { Action } from '@ngrx/store';
import { Effect, Actions, toPayload } from '@ngrx/effects';

// Let's avoid re-duplicating magic strings, and gradually build our routes up by composing functions
const route = (url: string[]) => go(url);
const zooRoute = (url: string[]) => route(['/zoo', ...url]);
const weaselRoute = (extras: string[] = []) => zooRoute(['weasels', ...extras]);
const weaselList = () => weaselRoute();
const weaselDetail = (id: number) => weaselRoute([id.toString()])

@Injectable()
export class RoutingEffects {
  constructor(
    private actions$: Actions,
  ) { }
  
  @Effect() gotoWeasels = this.actions$
    .ofType('WEASEL_LIST')
    .map(() => weaselList());

  @Effect() gotoWeaselDetail = this.actions$
    .ofType('WEASEL_DETAIL')
    .map(toPayload) // extract the payload
    .map(id => weaselDetail(id));
}
```

All that remains is to register these effects in our app's module.  And then we have a nice, DRY, managed route engine.  If at any point we redesign our URL scheme, the change to the list of strings will only happen in *one* spot.  We are also free to chain in any other side-effects to these pipelines, such as:

```typescript
@Effect() gotoWeasels = this.actions$
   .ofType('WEASEL_LIST')
   .switchMap(() => someAsyncThing())
   .do(() => console.log('Effect managers are a neat pattern'))
   .map(() => weaselList());
```

What we've done is put together an *internal API* for our app's routing.  Rather than demanding that our componenents inject Angular's `Router`, and call direct methods on it, we've encapsulated this 'low-level' implementation of our routing, and exposed it from behind a stable interface of human-friendly messages.
