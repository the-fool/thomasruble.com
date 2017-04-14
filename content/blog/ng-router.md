+++
date = "2017-04-02T21:24:05-05:00"
title = "don't use angular's router"
tags = ["spa", "ngrx", "angular"]
+++

# Abstract

*This little polemic assumes a working knowledge and high esteem of the `ngrx/effects` lifestyle.   It just offers a neat `ngrx` pattern that improves app happiness.*

Don't use Angular's built in router.  At least, do not use it directly.  Let's say you have a zoo app, and you want to route to a detail view of the 77th weasel.  Calling `router.navigate(['zoo', 'weasels', 77])` in your controller is bad for 3 reasons:

1. Changing routes like this is an unmanaged side-effect.
2. Visiting the 77th weasel requires knowing the magical list of string constants -- one change to your route config and you have to track down all these magic strings.
3. It is an imperative command floating out in the wide-open, ie, it is not safely changed to the end of a function.

We can fix all this with a simple pattern: a **route effect manager**.  Instead of calling route changes directly with Angular's router, we can use `ngrx/store` to dispatch nice, DRY, semantically friendly messages.  _Por ejemplo_:

```typescript
class GotoWeaselDetail {
  readonly type = 'WEASEL_DETAIL';
  constructor(public payload: number) {}
}

. . . .

const msg = new GotoWeaselDetail(77);
store.dispatch(msg);
```

That above is what we do in our smart component controller.  Then, in our app we have a bunch of functions registered with `ngrx/effect`.  These will make up our **route effect manager**:

```
import { go } from '@ngrx/router-store';

 . . . 
 
 @Effect() gotoWeaselDetail = this.actions$
     .ofType('WEASEL_DETAIL')
     .map(msg => msg.payload)
     .map(id => go(['zoo', 'weasel', id]));
```

We'll break down the details with complete code below.  Suffice it to say for now that we define the implementation of detailed weasel routes *once*, and everywhere else in the app use our store's dispatcher as a nice *interface* for invoking these side-effects.  We get all the benefits of Redux and managed-effects, plus extremely DRY code -- and this because we abstain from using Angular's router!


# What's the big deal?

There are 2 things that matter when it comes to judging correct code:  efficiency and maintainability.  Give a developer 10 implementations of a program which all produce the same output, what else is there to appraise them by besides speed and artful elegance?  The **routing manager** pattern in this blurb is just about increasing code maintainability (although this does make your development hours more efficient!).

Angular provides a router of the box, and the way it works is that any part of your codebase is free to command a route-change by passing it a list of strings representing the desired URL.

As we listed above, this ain't such a great way to do things.

  First, freely giving your code the power to initiate side-effects is asking for trouble.  Placing our effects inside an `ngrx/effect` manager gives us so many nice benefits, not the least of which is the ability to track every move our app makes through the excellent `redux-devtools` (hooked up thanks to `ngrx/store-devtools`).

Second, *URL strings are an implementation detail of a **semantically** meaningful view*.  That is, we should be able to refer to our different views by meaningful names -- the fact that the URL bar changes is an essential side-effect.  We should be free to change the string patterns in our URL scheme (or get rid of URL-based nav altogether!) and still have the same semantics with our app's route code.  Right?!  Am I the only the one who once decided to change URL scheme slightly, and had to hunt down and destroy dozens of incorrect `href=` strings  . . . 

Lastly, if we bring in route changes under the big tent of our `ngrx/store` message dispatcher, then we are that much closer to designing our app with a single unified internal API.  When you want to do something in your app, just dispatch a message to your store.  Always follow the opportunity for unity.

# Show me the code

