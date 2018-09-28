defmodule PRJ2.Main do
  use GenServer
  require Logger

  @moduledoc """
  Documentation for PRJ2.
  """

  def start_link(noOfNodes) do
    GenServer.start_link(__MODULE__,{noOfNodes},name: :genMain)
  end

  def getMain do
    self()
  end

  def init(inputs) do
    state = init_state(inputs)
    {:ok, state}
  end

  def init_state(inputs) do
    noOfNodes = elem(inputs,0) || 5
    nodes = []
    completedNodes = %{}
    {noOfNodes, nodes, completedNodes}
  end

  def handle_call({:updateNodes, nodes}, _from, {noOfNodes, _}) do
    {:reply, {noOfNodes, nodes}}
  end

<<<<<<< Updated upstream
  def startNode(acc) do
    newNode = PRJ2.Noded.start_link([])
    elem(newNode,1)
  end

  def createNodes(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.map(list, fn n ->  startNode() end)
  end



  def findNeighbours(index, nodes, topology,noOfNodes, nodeCoordinates) do
=======
  def findNeighbours(index, nodes, topology,noOfNodes) do
>>>>>>> Stashed changes
    case topology do
      "line" ->
        cond do
          index==0 ->
            [elem(nodes, index + 1)]
          index==(noOfNodes - 1) ->
            [elem(nodes, index - 1)]
          true ->
            [elem(nodes,index+1),elem(nodes,index-1)]
          end
          "full" ->
            Lists.delete_at(nodes,index)
          "rand2d" ->
            currentNodeCoordinate = Enum.at(nodeCoordinates,index)
            neighbours = Enum.reduce(nodeCoordinates, {0,[]}, fn coordinate,acc ->
            dist = math.sqrt(math.pow(elem(currentnode,1) - elem(coordinate,1)) + math.pow(elem(currentnode,0) - elem(coordinate,0)));
            index = elem(acc,0)
            neighbour = elem(acc,1)
            neighbour = if dist<0.1 do
               [elem(node,)] + neighbour
            else
              neighbour
            end
            {index +1, neighbour}}
            elem(neighbours,1)
    end
  end

  def startNodeGossip(acc) do
    newNode = PRJ2.NodeGossip.start_link({[]})
    Tuple.append(acc,elem(newNode,1))
  end

  def createNodesGossip(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.reduce(list,{}, fn n,acc ->  startNodeGossip(acc) end)
  end

  def handle_cast({:startGossip, msg}, {noOfNodes, _, completedNodes}) do
    nodes = createNodesGossip(noOfNodes)
    topology = "rand2d";
    nodeCoordinates = if topology == "rand2d" do
      Enum.reduce(0..noOfNodes, [],fn index,acc -> acc = [{rand.uniform(),rand.uniform()}] ++ acc end)
    end
    Enum.each(0..(noOfNodes - 1), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, topology ,noOfNodes)}) end)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    IO.inspect nodes
    IO.inspect randNodeIndex
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitMessage, "Su is too scared of ghost, and she won't sleep for 7 days alone."})
    {:noreply, {noOfNodes, nodes, completedNodes}}
  end

  def startNodePushSum(acc, index) do
    newNode = PRJ2.NodePushSum.start_link({index + 1, 1})
    Tuple.append(acc,elem(newNode,1))
  end

  def createNodesPushSum(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.reduce(list,{}, fn n,acc ->  startNodePushSum(acc, n) end)
  end

  def handle_cast({:startPushSum, s, w}, {noOfNodes, _, completedNodes}) do
    nodes = createNodesPushSum(noOfNodes)
    Enum.each(0..(noOfNodes - 1), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, "line",noOfNodes)}) end)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    IO.inspect randNodeIndex
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitSum, {s, w}})
    {:noreply, {noOfNodes, nodes, completedNodes}}
  end

  def handle_cast({:notify, nodePId}, {noOfNodes, nodes, completedNodes}) do
    completedNodes = Map.put(completedNodes,nodePId,true)
    IO.inspect(completedNodes)
    if map_size(completedNodes) == noOfNodes do
      IO.inspect "Convergance"
    end
    {:noreply,{noOfNodes, nodes, completedNodes} }
  end

  def handle_call(:getstate,_from,state) do
    {:reply,state,state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    Logger.info("fdfew")
    {:noreply, state}
  end
end
