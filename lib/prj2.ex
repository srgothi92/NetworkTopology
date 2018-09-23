defmodule PRJ2.Main do
  use GenServer

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

  def startNode(acc) do
    newNode = PRJ2.Noded.start_link([])
    elem(newNode,1)
  end

  def createNodes(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.map(list, fn n ->  startNode() end)
  end

  def findNeighbours(index, nodes, topology,noOfNodes) do
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
          
    end
  end

  def handle_cast({:startGossip, msg}, {noOfNodes, _, completedNodes}) do
    nodes = createNodes(noOfNodes)
    Enum.each(0..(noOfNodes - 1), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, "line",noOfNodes)}) end)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    IO.inspect randNodeIndex
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitMessage, "Su is too scared of ghost, and she won't sleep for 7 days alone."})
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
end
