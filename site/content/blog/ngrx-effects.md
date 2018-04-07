+++
date = "2017-03-23T21:24:05-05:00"
title = "ngrx/effects: why and when?"
tags = ["redux", "ngrx", "angular", "spa"]
description = "ngrx/effects offers a pattern to decouple our imperative side-effect code from our state-management strategy"
keywords = ["ngrx", "effects", "redux", "angular"]
+++

# Abstract

Angular has `ngrx/store` & `ngrx/effects`.  When it comes to using `ngrx/store`, it seems the dust has settled on the virtue of a redux-esque store for state-management.  But I've noticed people still toeing the water with effect-management.  The following explores what's at stake, while using a classic Angular HTTP data-service as an example.  I'll show a way to rein in XHR stuff, and make code more reusable & composable.  Spoiler: `ngrx/effects` bestows great happiness and good fortune.

# I mean . . . what *is* redux, *maaaann*?

That *model-view-controller* design sure has staying power, doesn't it?  It's easy to speculate why.  We know that separating concerns & isolating responsibilities makes code easier on the gulliver.  So let's go down to bedrock: what are the most *basic* responsibilities a program can be split into?

Consider two programs chained with the 'nix pipe: `cat | grep`.  Each program takes an input, operates on that input, and produces an output.  Can't get much simpler than this.  Now, 'MVC' is an **I/O process** by another name, smelling as sweet.  The *essential shape* of the input is the **model**, the *actual output* is the **view**, and all the processing that happens in between is the **controller**.  The model is the contract we make with our program's input, and the view is the contract we make with the program's output.  Now, 'controller' is kind of an overloaded word -- is control really what's at stake?  The **c** in MVC is really just an effectful function: it takes in a model, functions a little, and outputs.  It would be nice to name the pattern MVF(unction), or MVU(pdate) -- but that ship has sailed.

**Redux** is just MVC all over again -- but *this time we mean business*.  Redux is the thought that, "Hey, it's not 'models-views-conrollers' -- it's just one of each!"  After all, a redux reducer is just *one function*, and the whole app state is modelled by *one type*.

![mvc eye mouth brain](/img/mvc.png "Logo Title Text 1")

It's a Cartesianism of sorts. Design our program so it has a single constellation of sensory inputs, a single way to voice its results, and -- most importantly -- a single brain through which *everything* passes.

# Why use ngrx/effects?

To get in the mood, we must first ask:

## What's the deal with effects?

It's easy to think of your redux store as just a way to update the state of your app.  After all, the most famous part of a store -- The Reducer -- is just a function that takes two arguments (a message, and a state) and returns a state.

```elm
type Reducer = (Message, State) -> State
```

But this function definition does not tell the full story.  A lot goes on in a brain, even though we can't see it from the outside.  À propos our topic, the so-called 'store' can also be the main conduit for all of our app's *side effects*.  What is a side-effect?  It's something that happens which could never be indicated by that function definition up above.  If an `http` call happens in the middle of a function call, does it make a sound?  Side-effects are secretive, sneaky things -- they happen in the dark, outside of the reach of our type-definitions.

![side effect ghost](/img/ghost.png "Logo Title Text 1")

They haunt our functions -- ethereal denizens of some astral plane beyond the sway of static type algebra.  But we can corral them, and maybe even leash them, if we bring them under the dominion of our ngrx/redux flow.

## Bad-old Angular

Since the dawn of Angular, the prevailing technique has been to make a bunch of micro-mvc-lets out of **services**.  They would handle updating, storing, and exposing our state.  These 'services' were a good fit, because they were guaranteed to be singletons within well-defined scopes.  We could stick bits of data in them, and get it back later.  We could also call *methods* on a service which could, for example, trigger an XHR request (side-effect) and then a view component could get the new data out of the service.

Something like this:

```typescript
/* our singleton service */
class WhaleService {
  whaleCache: Whale[] = [];
  
  constructor(private http: Http) {}
  
  public fetchWhales() {
    return this.http
      .get('/api/whales')
      .map(res => res.json())
      .do(ws => {this.whaleCache = ws;}); 
    }
    
    public get cache() {
      return [...this.whaleCache];
    }
}

/* a needy view component somewhere */
class WhaleListView {
  whales: Whale[] = [];

  constructor(whaleSvc: WhaleService) {
    whaleSvc.fetchWhales()
     .subcribe(ws => this.whales = ws)
  } 
}

```

Whoever wants the whales depends on getting the `WhaleService` injected, and then can choose to snag the cache or call a method that triggers an XHR.  The service is the single source of truth for whales, and the gateway to the backend API in the great beyond.  True, we can gussy up our service with a public `rxjs/Subject`, which can emit values and save up from needing to make imperative calls on the service.  But that's not the issue we're here about.  The problem is that Whales are in their own module, with their own rules, getters, setters, etc . . . When we add Krill into the mix, we'll need a way to orchestrate updates between these two models.  Complexity will ensue.

## Good-new redux

The `ngrx/store` keeps things nice and simple.  If a component needs Whales, it injects the `Store`.  If it needs Krill, it injects the `Store`. And so on.  Also, if it needs to feed krill to a whale, the `Store` is again sufficient.  

```typescript
const { assoc } = require('ramda');

class FeedWhales {
  readonly type = 'FEED';
  constructor(public payload: Krill[]) {}
}

function reducer(whales: WhaleState, {type, payload}: Action): WhaleState {
  case 'FEED':
    return whales.map(assoc('krill', payload));
  default:
    return whales;
}
```

Dispatch a message `store.dispatch(new FeedWhales(krill))` and the update will take care of itself in the reducer logic.  This takes care of our state management.  So far so good.

But how do we get new whales from our whale-api?


## Revenge of the Service

Pure functions are nice, but sometimes our programs *do things* and *react to things done*. Making an XHR to a server is a prime example, since we both poke the outside world, and (almost) always look for it to poke us back.

A service (or `provider` if you like) is great for this.  They are the layer in app which is responsible for marhsalling data, and mapping commands to url endpoints.  All the special contracts with a remote server can be taken care of in our Angular service.  They encapsulate the bundling up of args into a `Request` and then the de-serializing of the response to some JS-friendly format (eg chaining `.map(res => res.json())`).

The question is *how do we get data from our service into our* `Store`?

Let's say our whale `reducer` had a `'LOAD'` action, which just replaced our `WhaleState` with a new list of whales:

```typescript
class LoadWhalesSuccess {
  readonly type = 'LOAD_WHALES_SUCCESS';
  constructor(public payload: Whale[]) {}
}

function reducer(whales: WhaleState, {type, payload}: Action): WhaleState {
  case 'LOAD_WHALES_SUCCESS':
    return [...payload];
    
  /* . . . . */
   
  default:
    return whales;
}
```

One way to use this reducer action in conjunction with XHR is to chain it our `WhaleService` method:

```typescript
/* our service, with no state management
   it's just a proxy to a backend server */
class WhaleService {
  constructor(
    private http: Http,
    private store: Store<State>
  ) {}
  
  public fetchWhales() {
    return this.http.get('/api/whales')
      .map(res => res.json())
      .do(ws => {
        const msg = new LoadWhalesSuccess(ws);
        this.store.dispatch(msg);
       })
  }
}
```

In this case, a component that wants whales might do this:

```typescript
class WhaleOfAView implements OnInit {
  whales$: Observable<Whale[]>;
  constructor(
    private store: Store<State>,
    private whaleSvc: WhaleService
  ) {
    const selector = (s: State) => s.whaleState;
    this.whales$ = store.select(selector);
  }
  
  ngOnInit() {
    // go get 'em, service!
    this.whaleSvc
      .fetchWhales()
      .subscribe();
  }
}
```

So much for only needing to inject `Store`. Now our view component not only need to know about how to get whales from the store, but it also needs to know to request whales from the backend.  It is coupled to our `WhaleService`.  Yikes!

Not only that, but in order to get some fresh whale-data, someone needs to call a method on the whale service.  It doesn't matter if it's a `CanActivate` or `Resolve` guard, or the view `Component` itself -- there is going to be a procedural stink with this setup.

Not only that!  But! Our `WhaleService` itself is coupled with our `Store`!  If we change the `LoadWhales` messaging API with our `Store`, or get rid of it, we've got to make a change in the `WhaleService`, too.

If only there was some way we could get declarative code, decoupled modules, and an orthogonal dependency archetecture . . . 


## Here is the ngrx/effects part

Should our state be a function of side-effect tasks, or should those tasks be a function of state?  That is, should our `WhaleService` get called directly and trigger an update to state, or should the `WhaleService` stuff be subsumed in our store pipeline?  The second option, please.  The idea with using an *effects manager* is that our view components *do not call methods on services*.  In fact, all they end up doing is subscribing to our `Store` and dispatching messages to it.  The `Store` is responsible for making a subsequent call to `WhaleService`.

We want our view component (or route guard, or whatever) to dispatch a message to the `Store`, and trust that the `Store` will take care of the necessary `WhaleService` calls.  What will happen is that the `WhaleService` is no longer a free agent, open for business throughout our app, but gets contained and owned by a managed effect-pipeline inside our ngrx-centered code.

Here is what we do:

```typescript
/* the command to go get whales */
class LoadWhales {
  readonly type = 'LOAD_WHALES';
  readonly payload = null;
}

/* fine-grain control of errors */
class LoadWhalesError {
  readonly type = 'LOAD_WHALES_ERROR';
  constructor(public payload: any) {}
}

/* success message, with a payload of fresh whale */
class LoadWhalesSuccess {
  readonly type = 'LOAD_WHALES_SUCCESS';
  constructor(public payload: Whale[]) {}
}

import { of } from 'rxjs/observable/of';
import { Effect, Actions } from '@ngrx/effects';
import { WhaleService } from 'whale.service';

export class WhaleEffects {
  constructor(
    private actions$: Actions,
    private whaleSvc: WhaleService
  ) {
  
  @Effect() loadWhales = this.actions$
    .ofType('LOAD_WHALES')
    .switchMap(() => 
       this.whaleSvc
         .fetchWhales()
         .map(ws => new LoadWhalesSuccess(ws))
         .catch(er => of(new LoadWhalesError(er))));
  }
```
If you haven't seen an `ngrx/effect` example before, let's quickly explain what's happening.  The `@Effect()` decorator gears a function into our `Store`-metabolism, so that when a message is dispatched, this function responds to it.  Just like a reducer.  The `ofType()` operator is a filter, which only lets certain events to continue down the chain.  This effect is only interested in the `'LOAD_WHALES'` message.  Now, an effect has a type signature: it must return an `Observable<Action>`.  This return gets unboxed in the `Store` and used in a fresh `store.dispatch()`.  So, we need to `.map()` our values into an `Action`, even if we're error-handling (hence the `of()` call, which returns an `Observable` from that `catch` block -- it's a little weird, c'est la vie).

![effects send messages](/img/effects.png "Logo Title Text 1")

Back at it.

The call to `WhaleService.fetchWhales()` happens deep within the nice, cozy confines of a managed pipeline.  It's boxed up, and other parts of our app don't even need to know it's there.  All they do is make a **declarative** request: `store.dispatch(new LoadWhales())`. 

That is, our view now becomes:

```typescript
class WhaleOfAView {
  whales$: Observable<Whale[]>;
  constructor(
    private store: Store<State>,
  ) {
    const selector = (s: State) => s.whaleState;
    this.whales$ = store.select(selector);
    
    store.dispatch(new LoadWhales());
  }
}
```

Gone is the service.  Just dispatch a message, and then: BAM!  New whales appear.  If we ever change our service, or ditch it, then we only need to make chages in the *effect* pipelines that use it -- and since these pipelines are reusable and composable, there probably won't be many.

And our service becomes:

```typescript
class WhaleService {
  constructor(
    private http: Http,
  ) {}
  
  public fetchWhales() {
    return this.http.get('/api/whales')
      .map(res => res.json());
  }
}
```

Gone is the `Store`.  Our service has one role, which is marshalling data to-and-fro with a backend server.  This separation is doubly beneficial, since any change to our `Store` API does not require re-coding our `WhaleService` -- the service *knows nothing* about the `Store` implementation. Ha!




## The payoff

So, our data-services don't need to know about the implementation of our `Store`, and our view components don't need to know about the implementation of our data-services.  This responsibility got passed up to the `Store`.  But this is more than just a shell game.  Just as how grouping all state-management into one domain gives us code-joy, so does grouping our effect management.  Once we step outside of the land of trivial examples into a regular complicated app, we can avail ourselves of the fact that all our effects take place in `Observable` pipelines, which means we can compose 'em all.

But that's not all -- since an `ngrx` `@Effect` function can return an `Action`, the effects can daisy-chain on each other.  For example, there could be another effect listening to type `'LOAD_WHALE_ERROR'` which sends an XHR to some error-logger on another service.  No matter what effectul feature you need, you can do it by chaining & composing these things.

![The One](/img/one.png "Logo Title Text 1")

We are doing MVC the right way -- with a single Brain/Controller/Updater thing.  It provides a **unified** and **declarative** interface for the whole rest of our app code.  We don't call methods on a multitude of services, we just dispatch messages and subscribe to events through a single gateway.  Our app is gathered together through one pattern that manages both our state and our effects.

It's also worth adding that `ngrx` (and redux) have great tooling, which includes code-instrumentation for free.  The [ngrx/store-devtools](https://github.com/ngrx/store-devtools) module let's you track the state of your app at every message juncture.  Since all our effects are done through the ngrx-metabolism, we can benefit tremendously from the auto-logging.

Now go forth and effect!
