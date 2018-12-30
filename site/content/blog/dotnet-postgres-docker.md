+++
date = "2018-11-04T21:24:05-05:00"
title = "dockerize .net core and postgres"
description = "Quickly scaffold a .NET Core & Postgres app with Docker"
keywords = ["C#", "Angular", ".NET Core", "Postgres", "Docker"]
tags = ["Docker", ".NET", "Postgres"]
+++
<!-- markdownlint-disable MD002 MD041-->

## Abstract

In this tutorial, you'll learn how to set up a fresh [.NET Core](https://docs.microsoft.com/en-us/dotnet/core/) project connected to a [PostgreSQL](https://www.postgresql.org/) database.  Instead of going through the hoops to install these packages on your OS, we'll get up and running the easy way: with [Docker](https://www.docker.com/).  Docker will take care of all the heavy lifting when it comes to installing these packages & coordinating their execution.  In fact, it's so easy to develop with Docker, we'll throw in an [Angular](https://angular.io/) app just because we can!  By the end, we'll have a full web-app framework in place, complete with a client, REST API, and database.

## Show me the code!

You can get [the finished project template here](https://github.com/the-fool/Dotnet-Postgres-Docker).  

To run the app, make sure Docker and [Docker-Compose](https://docs.docker.com/compose/) are installed on your machine, and then:

```bash
git clone https://github.com/the-fool/dotnet-postgres-docker
cd dotnet-postgres-docker
docker-compose up
```

That's it!  After a few minutes, you'll be able to visit the Angular app at `localhost:4200` and the REST API at `localhost:5000`.

Read on to build this up from scratch yourself...

## Application structure

We've been tasked to develop a web app for the international retail juggernaut **Gadget Depot**.  The CTO wants a web app to display Gadget Depot's current inventory.  Simple enough, we say, that'll be $50,000 and we'll have it done in 30 minutes.  We're going to accomplish this with a .NET Core web api, backed by PostgreSQL, and consumed with an Angular client.  Start the timer, and let's code! 

Pick a spot in your filesystem, and make the root project directory.

```bash
mkdir gadget_depot
cd gadget_depot
```

It'll be nice to keep the server code & client code totally separate.  The backend is _merely_ a API service.  It is not responsible for presentation.  All the UI code will be in its own separate module, which consumes our API.  To indicate the independence of the frontend and backend, make 2 sub-directories in the root of the project.

```bash
# at the project root
mkdir Frontend
mkdir Backend
```

Now we need to scaffold out the boilerplate code for both our projects.  Nothing stops you from writing it by hand, following the [completed code](https://github.com/the-fool/dotnet-postgres-docker) as a guide. However, Microsoft & Angular each provide tools for generating starter-templates.  We'll use those tools to save us some time & tedium.  

### Scaffold .NET Core backend

Let's scaffold the backend first, using the `dotnet` program.

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

In the `Backend` directory, you now should have a file tree resembling the following:

```text
│   GadgetDepot.sln
│
└───GadgetDepot
    │   appsettings.Development.json
    │   appsettings.json
    │   GagdetDepot.csproj
    │   Program.cs
    │   Startup.cs
    │
    ├───bin
    │
    ├───Controllers
    │
    ├───Models
    │
    ├───obj
    │
    ├───Properties
```

Notice that we used a Dockerized `dotnet` executable.  If you already had the `dotnet` program installed on your OS, you could just use that -- or could you?  One concern is _which version_ of `dotnet` are you running?  And if you udpate it for this project, would you then break your SDK for existing projects in your environment?  Docker to the rescue.   We were able to  scaffold all this code through without needing to worry about platform-specific installation of `dotnet`.

### Scaffold Angular frontend

No surprise: We can also leverage Docker for creating our Angular app!

Go back to the root of our project, and on into the Frontend dir.

```bash
cd ..
cd Frontend
```

In order to generate code for a simple Angular app, the command to run is `ng new gadgets --minimal --directory ./`.  Without needing to install the `ng` program, we're going to use a Docker image that contains the [Angular CLI tool](https://cli.angular.io/).  

```bash
docker run -v $(pwd):/app -w /app johnpapa/angular-cli ng new gadgets --minimal --direc
tory ./
```

After a few minutes, you should have a fully armed and ready to use Angular app.

The last step is to arrange these separate modules so that they boot up the right way, and can network with each other.

### Docker-Compose enters the ring

To orchestrate multiple containers, we'll use [Docker Compose](https://docs.docker.com/compose/).  It's a handy tool for configuring your Dockerized apps to work together.

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

One piece especially worth pointing out is the `local_postgres_data` volume.  By declaring a "volume" we can _persist_ our database state beyond the lifetime of the `db` container.  The call to create a volume allocates space on the host OS which outlives the destruction of a container.  When we reboot our PostgreSQL service, the database will have retained all its tables & rows, ready to go as if nothing had happened.  If we didn't map the container's `/var/lib/postgresql/data` dir to our host filesystem, the container would boot with fresh state when created.  In some cases you might want this behavior!  But for development, it's convenient to keep a constant state of the db.

Finally, notice that `web` and `client` services specify a `build` property.  This property tells Docker where to look for a `Dockerfile` it can use to build the containers.  Right now, it wouldn't find one.  So let's add a `Dockerfile` to each the `./Frontend` and `./Backend` directories.

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

Each of these are very similar & straight forward.  They each allude to an `entrypoint.sh` script, which will get run by default when the container starts.

### Write the startup scripts

For the last bit of Docker plumbing, we need to write an entry script for each of our services.  This script acts as the 'bootup' command for the containers.  The frontend and the backend scripts resemble each other closely -- they each install dependecies and start a dev server.

For `./Backend/entrypoint.sh`

```bash
#!/bin/bash

set -e

dotnet restore

# test the DB connection
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

The .NET script restores its packages, updates the databse, and then runs a server in dev mode.  The Angular scripts installs packages, and boots up a dev server.  Easy as pie.

Now, for the grand finale, we can boot up our whole, orchestrated app with a single command in the root directory:

```bash
docker-compose up
```

With one line, all the containers will build & configure themselves, ready to provide a bleeding edge inventory listing for Gadget Depot!

## Add Postgres To .NET Core

Well -- not quite!  We've scaffolded all the Docker features of the app, but now we need to hack on the application source code to get things in line.  Out of the box, .NET Core is not expecting to work with PostgreSQL -- this is the first feature we're going to fix.

### Add the Npgsql dependency

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

Next, we need to give our app with a connection string for the dockerized PostgreSQL database.  This connection string specifies the username, password, host address, and database name for our connection.

### Configure .NET database connection

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

Notice the key=value: `Server=db`.  Where does the hostname `db` come from?  This is just the name we gave our database service in the `docker-compose.yml`.  Internally, Docker sets up a kind of DNS for addressing services from within the networked containers, where each service's name functions as its hostname.  So, directing the .NET program to the hostname `db` will send it straight toward the PostgreSQL instance.

### Add the Npgsql Entity Framework service

The last bit of code needed to set up our PostgreSQL connection in the .NET app is an Entity Framework adapter.  

We'll add this adapter service to the `Startup` class in the `Backend/GadgetDepot/Startup.cs` file.  Update the `ConfigureServices` method in your `Startup` class so that it includes the call to the `IServiceCollection.AddEntityFrameworkNpgsql` method, making use of the connection string we created up above.

```csharp
public class Startup
{
  public Startup(IConfiguration configuration)
  {
    Configuration = configuration;
  }

  public IConfiguration Configuration { get; }

  public void ConfigureServices(IServiceCollection services)
  {
    services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_1);

    //
    // Add this following call to provide PostgreSQL support
    //
    services.AddEntityFrameworkNpgsql().AddDbContext<DbContext>(options =>
      options.UseNpgsql(Configuration.GetConnectionString("DbContext")));
        
  }

  public void Configure(IApplicationBuilder app, IHostingEnvironment env)
  {
    if (env.IsDevelopment())
    {
      app.UseDeveloperExceptionPage();
    }
    else
    {
      app.UseHsts();
    }

    app.UseHttpsRedirection();
    app.UseMvc();
  }
}
```

That'll do it!  Now you have an ASP.NET Core app communicating with PostgreSQL.  Congrats!  All that remains is to load up some gadgets, and display them in the Angular app.  Gadget Depot is going to have its deadline met.

## Build the API

Time to build out the REST API for our gadgets.  This section isn't really about PostgreSQL or Docker in particular, and touches on the same topics that a bunch of other ASP.NET core tutorials already cover very well.  So, while this part will go by quickly, take a gander at the [official Microsoft docs](https://docs.microsoft.com/en-us/aspnet/core/data/ef-rp/intro?view=aspnetcore-2.2&tabs=visual-studio) to learn more.

### Model a Gadget

For our requirements, a gadget is just a name and nothing else.  To model it in our app, go to the `GadgetDepot/Models` directory, add a new class `Gadget` in `Gadget.cs`:

```csharp
namespace GadgetDepot.Models {
    public class Gadget {
        public int Id { get; set; }
        public string Name { get; set; }
    }
}
```

That'll do just fine.  Next, we need to integrate this model declaration with our database.  In order to do this, we need to implement the `DbContext` interface, with our new `Gadget` class taking a leading role.

### Include Gadgets in the Database Context

Create the file `Backend/GadgetDepot/ApiDbContext.cs`, and write our custom Gadget Depot `DBContext` to include the `Gadget` model as so:

```csharp
using Microsoft.EntityFrameworkCore;
using GadgetDepot.Models;

namespace GadgetDepot {
  public class ApiDbContext : DbContext {
    public ApiDbContext(DbContextOptions<ApiDbContext> options) : base(options) { }

    public DbSet<Gadget> Gadgets { get; set; }
  }
}
```

This class declares that our app's persistenc layer has a set of gadgets, which will be implemented in PostgreSQL as a single table.

To use this context, simply swap out the `DbContext` that we declared in the `Startup` class. Be sure to add a `using GadgetDepot.Models` at the head of the file, and then make the change to the `ConfigureServices` method in the `GadgetDepot.Startup` class:

```csharp
public void ConfigureServices(IServiceCollection services) 
{
  services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_1);
  // DbContext -> ApiDbContext
  services.AddEntityFrameworkNpgsql().AddDbContext<ApiDbContext>(options =>
      options.UseNpgsql(Configuration.GetConnectionString("DbContext")));
}
```

With this change, Entity Framework Core will be expecting a table called "Gadgets" in the PostgreSQL database.  At this stage we're primed to make a migration file and update the schema of the db.  Navigate your shell to the `Backend/GadgetDepot` project and run the following commands to create & apply a migration.

```bash
docker run -v $(pwd):/app -w /app microsoft/dotnet dotnet ef migrations add Initial
docker run -v $(pwd):/app -w /app microsoft/dotnet dotnet ef database update
```

### Initialize the Database

As a final flourish, we can insert some test gadgets into the database.  Create the file `Backend/GadgetDepot/DbInitializer.cs` with the following class:

```csharp
using GadgetDepot.Models;
using System.Linq;

namespace GadgetDepot 
{
  public class DbInitializer 
  {
    public static void Initialize(ApiDbContext ctx) 
    {
      ctx.Database.EnsureCreated();
      var test = ctx.Gadgets.FirstOrDefault();
      if (test == null) 
      {
        ctx.Gadgets.Add(new Gadget { Name = "plumbus" });
        ctx.Gadgets.Add(new Gadget { Name = "flux capacitor" });
        ctx.Gadgets.Add(new Gadget { Name = "spline reticulator" });
        ctx.SaveChanges();
      }
    }
  }
}
```

The static `Initialize` method will programmatically make sure that the database `gadget` is in fact existent, and if the "Gadgets" table is empty, it will add a few test rows.

We can make this method run at startup time by inserting a call to `Initialize` in the `Main` method of the `Program` class.  The method has a dependency on a database context, and so we need to get that context from within `Main`.  Alter your `Backend/GadgetDepot/Program.cs` file to mimic the following:

```csharp
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace GadgetDepot 
{
  public class Program 
  {
    public static void Main(string[] args) 
    {
      var host = CreateWebHostBuilder(args).Build();
      using(var scope = host.Services.CreateScope()) 
      {
        var services = scope.ServiceProvider;

        var context = services.GetRequiredService<ApiDbContext>();
        var logger = services.GetRequiredService<ILogger<Program>>();

        try 
        {
          DbInitializer.Initialize(context);
        } 
        catch (Exception ex) 
        {
          logger.LogError(ex, "An error occurred creating the DB.");
        }
      }

      host.Run();
    }

    public static IWebHostBuilder CreateWebHostBuilder(string[] args) =>
      WebHost.CreateDefaultBuilder(args)
        .UseStartup<Startup>();
  }
}
```

The trick here is creating a scope wherein we can access the services -- most importantly, an `ApiDbContext` instance.  Passing this context into the `DbInitializer.Initialize` method allows it to make a connection with the database, and execute its routine.  

Note that this `Initiailize` call will run _every time_ the app boots.  In the future, we might want a more sophisticated way to condition whether or not we want this code to run, but for the sake of immediate development, this is good enough for Gadget Depot.

### Write an API Controller for Gadgets

To round out our API, we need to add a controller class for exposing the gadget data.  As with the steps it took to provision the DB, you can find an in-depth guide to this facet of ASP.NET programming in [other tutorials](https://docs.microsoft.com/en-us/aspnet/core/tutorials/first-web-api?view=aspnetcore-2.2&tabs=visual-studio).  We'll just copy in the code so we can get our Gadget Depot app delivered on schedule!

Create the file `Backend/GadgetDepot/Controllers/GadgetController.cs`:

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using GadgetDepot.Models;
using Microsoft.AspNetCore.Mvc;

namespace GadgetDepot.Controllers 
{
  [Route("api/[controller]")]
  [ApiController]
  public class GadgetsController : ControllerBase 
  {
    ApiDbContext ctx;

    public GadgetsController(ApiDbContext _ctx) 
    {
      ctx = _ctx;
    }

    [HttpGet]
    public ActionResult<List<Gadget>> Get() 
    {
      return ctx.Gadgets.ToList();
    }
  }
}
```

This is all it takes for `localhost:5000/api/gadgets` to return our list of gadget inventory in nice, JSONified form.  All that's left to do is make our Angular app consume this API.  


## Build an Angular Web Client

So long to the .NET code.  Now move over to the `Frontend` directory and get ready to write an Angular app.  Well, it's not going to be much of an app at all.  And Angular is certainly overkill for what we're setting out to accomplish.  But it's so easy to set up using Docker and the `ng` tool that we may as well lay a good foundation for future iteration on Gadget Depot's web app.

Change the `src/app/app.component.ts` file so that the main component will connect to the REST API backend:

```js
import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface Gadget {
  id: number;
  name: string;
}

@Component({
  selector: 'app-root',
  template: `
  <h1>Gadget Depot</h1>
  <ul>
    <li *ngFor="let gadget of gadgets">
      {{ gadget }}
    </li>
  </ul>
  `
})
export class AppComponent implements OnInit {
  gadgets: string[] = [];

  constructor(private http: HttpClient) { }

  ngOnInit() {
    this.http.get<Gadget[]>('http://localhost:5000/api/gadgets')
      .subscribe(gs => {
        this.gadgets = gs.map(g => g.name);
      });
  }
}
```

Be sure to import the `HTTPClientModule` in your `AppModule`, and your Gadget Depot client is minimally viable. 

## Wrap-up

We used Docker to build a whole full-stack web-app.  ASP.NET Core, PostgreSQL, and Angular all working together right out of the box.  Kudos!

To run your app, all that needs doing is a call to `docker-compose` in the root directory:

```bash
docker-compose up
```

Watch as all your services spring to life, networked with each other, in a cozy, containerized world unto themselves.  
