+++
date = "2018-04-04T21:24:05-05:00"
title = "make a metronome with python asyncio"
description = "Use Python's asyncio module to make a handy metronome"
tags = ["python", "asyncio", "async", "music", "midi"]
keywords = ["python", "asyncio", "async", "music", "midi"]
+++
<!-- markdownlint-disable MD002 MD041-->

## What we will build

We are going to make a *metronome* using Python's `asyncio` module.  Our metronome is going tick at a steady rate, executing a collection of subroutines at each tick.  I've used this module to control a light & music show -- but you can use this code for running _any_ operation at regular intervals.  The code is relatively straight-forward -- I just think it's a neat introdoction to the power of async IO!

## Intro to async IO

Python's `asyncio` module is an everything-and-the-kitchen-sink package of parallel & concurrent programming tools.  We're just going to look at a very simple use case for this library: running an infinite loop with a sleep in each iteration.

In synchronous single-threaded programs, calling `sleep()` does just that -- it puts the thread to sleep, and the thread does no work until it wakes up.  With Python's `asyncio` there is a kind of 'sleep' where the thread does not stop working, but instead gets a free pass for a time to do work elsewhere.  With calling `asyncio.sleep()`, the thread refrains from working at the current routine, and makes itself available to do work elswhere.  The single thread does not go to sleep -- it rushes off to do as much work as it can before being yanked back 'awake' to the place it briefly adjourned.

Without this `asyncio.sleep()`, if we wanted our program to keep working during a sleep, we would need more than 1 thread!  As anyone who has tried it knows: multithreaded programming is neither easy nor simple.  But, as we'll see, getting work out your program while putting a thread 'to sleep' is a cinch with `asyncio`.

The upshot: we're going to write code with infinite loops, 1 thread, and high-performance.

## Metronome spec time

We are going to make a metronome.  A metronome is used typically in music to synchronize a performance to a regular tempo.  Traditionally, a tempo is defined in terms of beats-per-minute.  It terms of code, our metronome is going to beat at regular intervals, and at each beat it will execute a collection of callbacks.

All our metronome needs is (1) the beats-per-minute tempo, and (2) a list of callbacks.  We can take a first pass at the code

```python
import asyncio
from typing import Callable, Any, List

CallBack = Callable[None, Any]
CallBacks = List[Callback]

class Metronome:
  def __init__(tempo: int, callbacks: CallBacks):
    self.tempo = tempo
    self.callbacks = callbacks

  async def start(self):
    while True:
      # tempo is beats-per-minute.  60bpm is a beat every 1 second
      sleep_time = 60 / self.tempo
      asyncio.sleep(sleep_time)

      for callback in self.callbacks:
        callback()
```

This is a good start!  It's a minimum viable metronome, for sure.  We instantiate the class with 2 arguments: a tempo and a list of callbacks.  The tempo is used for determining the sleep time, and at each beat in the loop, our metronome executes all the callbacks.

How can we improve it?  Let's make 2 changes.  The first will improve performance, and the second will improve the regularity of our sleep interval, so that the metronome does not drift much.

## 1. Async everywhere

I want to use my metronome for sending commands to things in the outside world.  Maybe my code will send MIDI messages, or control an array of LEDs.  This IO-bound work takes time -- time which can block our main thread.  This sort of IO-focused processing is what Python's `asyncio` library is made for!  If we ensure that our callbacks are all async subroutines, then we can mitigate the impact of IO on our code's performance.  This is just a simple change to our metronome's API & implementation.

Now with all async callbacks:

```python
import asyncio
from typing import Callable, Any, List, Awaitable

CallBack = Callable[None, Awaitable[Any]]
CallBacks = List[Callback]

class Metronome:
  def __init__(tempo: int, callbacks: CallBacks):
    self.tempo = tempo
    self.callbacks = callbacks

  async def start(self):
    while True:
      # tempo is beats-per-minute.  60bpm is a beat every 1 second
      sleep_time = 60 / self.tempo
      asyncio.sleep(sleep_time)

      for callback in self.callbacks:
        await callback()
```

It's a simple change with big consequences.  It ensures that our callbacks will not block our thread while waiting on IO to complete.

## 2. Prevent drift over the intervals

Making our callbacks asynchronous does not make them run faster.  The IO operations will still take time.  This time will create a drift in our metronome intervals, where one beat might take longer than another owing to how long it needed to wait for its callbacks to complete.  We need to keep track of the time it takes to run a beat's worth of callbacks to completion.  This is a simple enough feature to implement:

```python
import asyncio
import time
from typing import Callable, Any, List, Awaitable

CallBack = Callable[None, Awaitable[Any]]
CallBacks = List[Callback]

class Metronome:
  def __init__(tempo: int, callbacks: CallBacks):
    self.tempo = tempo
    self.callbacks = callbacks

  async def start(self):
    offset = 0

    while True:
      sleep_time = max(0, (60 / self.bpm - offset))
      asyncio.sleep(sleep_time)

      # start timer
      t0 = time.time()

      for callback in self.callbacks:
        await callback()

      t1 = time.time()

      # calc offset
      offset = t1 - t0
```

Now we are timing our callbacks, and reduce our sleep time accordingly.  This won't perfectly eliminate drift, but the minor variations between beats should be well within what a human ear can detect.