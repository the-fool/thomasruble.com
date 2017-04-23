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

Not [wat]('https://channels.readthedocs.io/en/stable/'), but why.  For pretty much the whole history of software, there was a handy solution to most problems with _performance_: just wait 1 year for CPU clock rates to improve.  Bingo!  Your program performs twice as fast!  But now the Age of Single-Threadedness is in decline, as CPU speed increases have begun mellowing out.  To improve our performance we need to make actual changes to the code and _architecture_ of our software.  We need to run multiple threads of execution in parallel.

Django Channels takes a familiar tack: a dedicated pool of worker processes consuming a task queue.  This is a _message passing_ paradigm.  Data is serialed and stuffed in a mailbox.  This is _not_ shared memory concurrency.  The benefit of this worker-process-pool & message-queue technique is that it is dead simple to implement (relative to 'shared mutable memory' models, at least).  We create a task, push it onto a queue, and eventually a free process will scoop it up and do the work.

Django Channels is a structural change in Django's web-server innards where we have a dedicated server that receives requests and subsquently _enqueues_ tasks, and a server (or pool of servers) that _consume_ those tasks.  Furthermore, since a 'task' and a 'consumer' are pretty generic notions, Django is no longer just built for the traditional HTTP request/response pipeline.

This is nothing novel.  In fact, most Django production environments are buoyed with software that follows this pattern: [nginx](https://www.nginx.com/blog/thread-pools-boost-performance-9x/) for managing a pool of HTTP consumers, [Gunicorn](http://docs.gunicorn.org/en/stable/design.html) for managing a pool of Python processes, and [Celery](http://docs.celeryproject.org/en/latest/userguide/workers.html) for managing a different pool of Python processes.  Maybe in the future of the Channels project we won't have a use for so many auxillary worker-pool managers.

# Oh, and WebSockets

I forgot to mention WebSockets -- Django Channels also provides a pretty neat way to do WebSocket-related things.  That's what we're about to get into.

