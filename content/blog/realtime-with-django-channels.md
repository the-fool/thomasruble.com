+++
date = "2017-04-12T21:24:05-05:00"
title = "real-time progress updates with django channels"
description = "Realtime progress updates through WebSockets with Django Channels"
tags = ["channels", "websocket", "django"]
keywords = ["django", "channels", "websocket", "realtime", "websockets"]
+++

# Abstract

What follows is a simple demo for using the [Delay Server](https://channels.readthedocs.io/en/stable/delay.html) in [Django Channels](https://github.com/django/channels) to deliver asynchronous real-time progress updates over web-sockets.  The demo backend will fire a long-running 'backround task', and then send progress updates at regular intervals to a WebSocket client.  We'll also distribute the load of sending and receiving WebSocket events with multiple queues and worker processes.


# Why Django Channels?

Not [wat](https://channels.readthedocs.io/en/stable/), but why.  For pretty much the whole history of software, there was a handy solution to most problems with _performance_: just wait 1 year for CPU clock rates to improve.  Bingo!  Your program performs twice as fast!  But now the Age of Single-Threadedness is in decline, as CPU speed increases have begun mellowing out.  To improve our performance we need to make actual changes to the code and _architecture_ of our software.  We need to run multiple threads of execution in parallel.

Django Channels takes a familiar tack: [a dedicated pool of worker processes consuming a task queue](https://channels.readthedocs.io/en/stable/concepts.html#what-is-a-channel).  This is a _message passing_ paradigm.  Data is serialed and stuffed in a mailbox.  This is _not_ shared memory concurrency.  The benefit of this worker-process-pool & message-queue technique is that it is dead simple to implement (relative to 'shared mutable memory' models, at least).  We create a task, push it onto a queue, and eventually a free process will scoop it up and do the work.

Django Channels is a structural change in Django's web-server innards where we have a dedicated server that receives requests and subsquently _enqueues_ tasks, and a server (or pool of servers) that _consume_ those tasks.  Furthermore, since a 'task' and a 'consumer' are pretty generic notions, Django is no longer just built for the traditional HTTP request/response pipeline.

This is nothing novel.  In fact, most Django production environments are buoyed with software that follows this pattern: [nginx](https://www.nginx.com/blog/thread-pools-boost-performance-9x/) for managing a pool of HTTP consumers, [Gunicorn](http://docs.gunicorn.org/en/stable/design.html) for managing a pool of Python processes, and [Celery](http://docs.celeryproject.org/en/latest/userguide/workers.html) for managing a different pool of Python processes.  Maybe in the future of the Channels project we won't have a use for so many auxillary worker-pool managers.

# Oh, and WebSockets

I forgot to mention WebSockets -- Django Channels also provides a pretty neat way to do WebSocket-related things.  That's what we're about to get into.

# The Problem:  Real-Time status updates at regular intervals

I was recently charged to write a web-server that gets requests from its web-client for starting a long-running task on _another_ server, and then sending the results back once it's complete.  The web-server is something of a proxy, brokering events between a backend service and a web-client.  Now, the backend service provided a way to get the progress of a task its working on, and I wanted to update the client at regular intervals with the status of the task.

One way to get regular updates is to require the _client_ to make many spaced-out requests.  The downside of this is processing overhead for the backend (not only with respect to the bulky HTTP packets, but also that every request needs to be authenticated afresh).  Rejected!

A better way is to use WebSockets.  That way, the client and the web-server can create a session, and the server can push updates straight to the client.  No need for the client to request them.  Nice, light, declarative . . . and fun!

What we need now is just a way to get our Django app to poll the backend service periodically, and then send the client an update.  And, no, we are not going to go this route in our Django code:

```python
# this is wrong, wrong, wrong
while not complete:
  sleep(1)
  current_status = poll_service(task_id)
  update_client(current_status)
  complete = current_status['complete']
```

What we want to do is _queue_ a slightly delayed task that polls the backend service.  We won't be putting threads to sleep.  Message queuing is also nice, light, declarative . . . and fun!

# Implementation Decision

To play with WebSockets in Django, there [are](https://django-websocket-redis.readthedocs.io/en/latest/) [options](https://github.com/GetBlimp/django-websocket-request).  But going forward it seems pretty safe to assert that Channels is going to be the _de jure_ solution, as well as _de facto_.

But what about our timeout intervals?

Typically, I reach for [Celery](http://www.celeryproject.org/) to address a problem like this.  With Celery you can specify a ['countdown'](http://docs.celeryproject.org/en/latest/userguide/calling.html#eta-and-countdown) for a task, so that it won't be consumed until a set time into the future.

Celery would be a perfectly fine solution! But it turns out that we can accomplish the feature with Django Channels alone -- without bringing in the whole Celery project.  _Nota bene: Channels is **not** (yet?) a replacement for Celery, but they do overlap in places._

Whereas Celery has a its 'countdown' attribute for its async tasks, Channels has a [delay server](https://channels.readthedocs.io/en/stable/delay.html) for handling 'delayed' tasks (i.e., tasks whose execution is meant to occur after at least a certain amount of time into the future).

So, no Celery needed!  We can get _both_ WebSocket goodness _and_ regular timeout intervals with the same Django library.  What a world!

# Let's build it




