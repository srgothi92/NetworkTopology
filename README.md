# Gossip Simulator

**The program implements Gossip and Push-Sum algorithm for Full Network,3D Grid,Random 2D Grid,Line,Sphere,Imperfect Line topologies. It takes the number of nodes, topology and algorithm as input. Based on the type of topology, it computes the neighbours and passes the message to a random neighbour.**

## Group Info

UFID: 8115-5459 Shaileshbhai Revabhai Gothi


UFID: 8916-9425 Sivani Sri Sruthi Korukonda

## Instructions
Valid values for topology: "sphere", "3dGrid", "line", "impline", "rand2d", "full"

To run the code for this project, simply run in your terminal:

```elixir
$ mix compile
$ iex main = PRJ2.Main.start_link(<topology>,<noOfNodes>)
$ iex GenServer.cast(<mainPid>,{:startPushSum,<s>,<w>})
$ iex GenServer.cast(<mainPid>,{:startGossip,<message>})
```
Example:
```elixir
$ mix compile
$ iex main = PRJ2.Main.start_link("3dGrid",50)
$ iex GenServer.cast(elem(main,1),{:startPushSum,0,0})
$ iex GenServer.cast(elem(main,1),{:startGossip,"blah blah"})

To run the code for the bonus part, simply run in your terminal:

```elixir
$ mix compile
$ iex main = PRJ2.Main.start_link(<topology>,<noOfNodes>, <bonus?>, <MaxNodesToKill>,<TimeInterval>)
$ iex GenServer.cast(<mainPid>,{:startPushSum,<s>,<w>})
$ iex GenServer.cast(<mainPid>,{:startGossip,<message>})
```
Example:
```elixir
$ mix compile
$ iex main = PRJ2.Main.start_link("3dGrid",50, true, 5, 10)
$ iex GenServer.cast(elem(main,1),{:startPushSum,0,0})
$ iex GenServer.cast(elem(main,1),{:startGossip,"blah blah"})
```

## Tests

To run the tests for this project, simply run in your terminal:

```elixir
$ mix test
```

## What is working

1. All the six topologies namely Full Network,3D Grid,Random 2D Grid,Line,Sphere,Imperfect Line are implemented for both Gossip and Push-Sum.
2. Convergance rate for each topology :


   a. Full : 100%
   
   
   b. 3dGrid : 100%
   
   
   c. Random2D : Starts converging after 300 nodes (for Gossip algorithm only)
   
   
   d. Sphere : 100%
   
   
   e. Line : 100%
   
   
   f. Imperfect Line : 100%

## Largest Network implemented:

The largest network implemented for each topology is as follows for Gossip (for reasonable amount of time):
   
   
   a. Full : 20000
   
   
   b. 3dGrid : 50000
   
   
   c. Random2D : 10000
   
   
   d. Sphere : 50000
   
   
   e. Line : 10000
   
   
   f. Imperfect Line : 40000
   
The largest network implemented for each topology is as follows for PushSum (for reasonable amount of time):
   
   
   a. Full : 4000
   
   
   b. 3dGrid : 4000
   
   
   c. Random2D : 15000
   
   
   d. Sphere : 3000
   
   
   e. Line : 1000 
   
   
   f. Imperfect Line : 5000

## Documentation

To generate the documentation, run the following command in your terminal:

```elixir
$ mix docs
```
This will generate a doc/ directory with a documentation in HTML. 
To view the documentation, open the index.html file in the generated directory.

