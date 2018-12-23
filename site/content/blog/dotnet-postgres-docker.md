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

Now is where we need to scaffold out the boilerplate code for both our projects.  Nothing stops you from writing it by hand, following the [provided code](https://github.com/the-fool/dotnet-postgres-docker) as a guide -- but you could also have most of the project code generated for you using Microsoft & Angular tools.  

Let's scaffold the backend first.

```bash
cd Backend
# create a new solution
docker run -v $(pwd):/app -w /app microsoft/dotnet dotnet new sln -n gadget_depot
# create the webapi project
mkdir GadgetDepot
docker run -v $(pwd):/app -w /app microsoft/dotnet dotnet new webapi -o GadgetDepot
# add the project to the solution
docker run -v $(pwd):/app -w /app microsoft/dotnet dotnet sln add GadgetDepot
```

If you had the `dotnet` program installed on your OS, you could just use that.  But, mostly to prove a point, you can also scaffold all this code through `docker` without needing to worry about platform-specific installation.

We can also leverage Docker for creating our Angular app!

Go back to the root of our project, and on into the Frontend dir.

```bash
cd ..
cd Frontend
```

Here we're going to use a Docker image that contains the [Angular CLI tool](https://cli.angular.io/).  Simply run the `new` command, specifying that we want a minimal app in the current directory.

```bash
docker run -v $(pwd):/app -w /app johnpapa/angular-cli ng new gadgets --minimal --direc
tory ./
```

After a few minutes, you should have a fully armed and ready to use Angular app.

The last step is to arrange these separate modules so that they boot up the right way, and can network with each other.

To orchestrate multiple containers, we'll use [Docker Compose](https://docs.docker.com/compose/).  It's a handy tool configuring your Dockerized apps to work together.

In the root of the project, create a file `docker-compose.yml`

```yaml
# /docker-compose.yml
version: "3"

volumes:
  local_postgres_data: {}

services: 
  web:
    build: ./Backend
    ports:
      - "5000:5000"
      - "5001:5001"
    volumes:
      - ./backend:/app
      - /app/GadgetDepot/bin
      - /app/GadgetDepot/obj
    depends_on:
      - db

  db:
    image: postgres:11.1
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USERNAME: postgres
    volumes:
      - local_postgres_data:/var/lib/postgresql/data

  client:
    build: ./Frontend
    ports:
      - "4200:4200"
    volumes:
      - ./frontend:/app
```

In this file, we declare our three separate _services_ comprising the app.  

    - `web` : the .NET Core project
    - `db` : the database
    - `client` : the Angular app

One piece especially worthy of attention is the `local_postgres_data` volume.  This is a way to _persist_ our database state beyond the lifetime of the `db` container.  The call to create a volume allocates space on the host OS which outlives the destruction of a container.  When we reboot our PostgreSQL service, the database will have retained all its tables & rows, ready to roll.  If we didn't map the container's `/var/lib/postgresql/data` dir to our host filesystem, the container would boot with fresh state when created.  In some cases you might want this behavior!  But for development, it's convenient to keep a constant state of the db.

Finally, notice that `web` and `client` services specify a `build` property.  This key will send Docker looking for a `Dockerfile` it can use to build the containers.  We need to add a `Dockerfile` to each the `./Frontend` and `./Backend` directories.

For the backend:

```dockerfile
# ./Backend/Dockerfile
FROM microsoft/dotnet:latest

COPY ./entrypoint.sh /
RUN sed -i 's/\r//' /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app

CMD /entrypoint.sh
```

And for the frontend:

```dockerfile
# ./Frontend/Dockerfile
FROM node:latest

COPY ./entrypoint.sh /
RUN sed -i 's/\r//' /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app

CMD /entrypoint.sh
```

Each of these are very similar & straight forward.  They each pass the buck to an `entrypoint.sh` script, which will get run by default when the container starts.

There is not much we need to get off the ground with the `entrypoint.sh` scripts.  They are each fundamentally a way to install dependecies and start a dev server.

For `./Backend/entrypoint.sh`

```bash
#!/bin/bash

set -e

dotnet restore

until dotnet ef -s GadgetDepot -p GadgetDepot database update; do
>&2 echo "DB is starting up"
sleep 1
done

>&2 echo "DB is up - executing command"

dotnet watch -p GadgetDepot run
```

For `./Frontend/entrypoint.sh`

```bash
#!/bin/bash

set -e

yarn

npm start
```

The .NET script simply restores its packages, updates the databse, and then runs a server in dev mode.  The Angular scripts similary installs packages, and boots up a dev server.

Now, for the grand finale, we can boot up our whole, orchestrated app with a single command in the root directory:

```bash
docker-compose up
```

With one line, all the containers will build & configure themselves, happy to serve the greater good of Gadget Depot!

## Add Postgres To .NET Core

Well -- not quite!  We've scaffolded all the Docker features of the app, but now we need to hack on the application source code to get things in line.  Out of the box, .NET Core is not expecting to work with PostgreSQL -- this is the first feature we're going to fix.

To teach .NET how to interface with PostgreSQL, we're going to add the [Npgsql](http://www.npgsql.org/efcore/index.html) library.  Simply add the reference to Npgsql to your `./Backend/GadgetDepot/GadgetDepot.csproj` file:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>netcoreapp2.1</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <Folder Include="wwwroot\" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>
  
  <ItemGroup>
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="2.1.2" />
  </ItemGroup>

</Project>
```

That's all for added dependencies!

Next, we need to provide our app with a connection string for our dockerized database.  This string will fill our .NET app in on the details of which username, password, host address, and name of the connected database.

Update your `appsettings.json` to resemble the following:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "System": "Information",
      "Microsoft": "Information"
    }
  },
  "ConnectionStrings": {
    "DbContext": "Username=postgres;Password=postgres;Server=db;Database=gadget"
  }
}
```

Note that `Server=db` relates to how we named our database service in the `docker-compose.yml`.  Internally, Docker sets up a kind of DNS for addressing services from within the networked containers, where each service's name functions as its hostname.  So, directing the .NET program to the hostname `db` will send it straight toward the PostgreSQL instance.
