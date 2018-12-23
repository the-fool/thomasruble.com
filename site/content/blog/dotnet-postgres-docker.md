+++
date = "2018-11-04T21:24:05-05:00"
title = "dockerize .net core and postgres"
description = "Quickly scaffold a .NET Core & Postgres app with Docker"
keywords = ["C#", "Angular", ".NET Core", "Postgres", "Docker"]
tags = ["Docker", ".NET", "Postgres"]
+++
<!-- markdownlint-disable MD002 MD041-->

## Abstract

In this article, you'll learn how to set up a fresh [.NET Core](https://docs.microsoft.com/en-us/dotnet/core/) project to use a [PostgreSQL](https://www.postgresql.org/) database.  We'll do this the easy way: using [Docker](https://www.docker.com/) to take care of all the heavy lifting when it comes to installing these packages.  In fact, it's so easy to use Docker, we'll throw in an [Angular](https://angular.io/) app just because we can.

## Show me the code!

Get [the finished project template here](https://github.com/the-fool/Dotnet-Postgres-Docker).  Make sure Docker and [Docker-Compose](https://docs.docker.com/compose/) are installed on your machine, and then:

```bash
git clone https://github.com/the-fool/dotnet-postgres-docker
cd dotnet-postgres-docker
docker-compose up
```

That's it!  After a few minutes, you'll be able to visit the Angular app at `http://localhost:4200`.

Read on to see how we build this up from scratch...

## Application structure

Our mission is to build a web app for the international retail chain **Gadget Depot**.  We're going to go about doing this with a basic .NET Core web api, backed by PostgreSQL, and consumed with an Angular client.  Let's make the root project directory.

```bash
mkdir gadget_depot
cd gadget_depot
```

It'll be nice to keep the server code & client code totally separate, so start with making 2 sub-directories.

```bash
# at the project
mkdir Frontend
mkdir Backend
```

Now is where we need to scaffold out the boilerplate code for both our 
