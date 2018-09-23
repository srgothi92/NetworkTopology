defmodule PRJ2.Main do
  use GenServer

  @moduledoc """
  Documentation for PRJ2.
  """

  def start_link(opts, noOfNodes) do
    GenServer.start_link(__MODULE__,{opts,noOfNodes}, opts)
  end

  def init(inputs) do
    state = init_state(inputs)
    {:ok, state}
  end

  def init_state(inputs) do
    noOfNodes = elem(inputs,1) || 5
    nodes = {}
    {noOfNodes, nodes}
  end

  def handle_call({:updateNodes, nodes}, _from, {noOfNodes, _}) do
    {:reply, {noOfNodes, nodes}}
  end

  def startNode(acc) do
    newNode = PRJ2.Noded.start_link([])
    Tuple.append(acc,elem(newNode,1))
  end

  def createNodes(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.reduce(list,{}, fn n,acc ->  startNode(acc) end)
  end

  def findNeighbours(index, nodes, topology,noOfNodes) do
    case topology do
      "line" -> 
        cond do 
          index==0 ->
            [elem(nodes, index + 1)]
          index==noOfNodes ->
            [elem(nodes, index - 1)]
          true ->
            [elem(nodes,index+1),elem(nodes,index-1)]
          end
    end
  end

  def handle_cast({:startGossip, msg}, {noOfNodes, _}) do
    nodes = createNodes(noOfNodes)
    Enum.each(0..(noOfNodes - 2), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, "line",noOfNodes)}) end)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    IO.inspect randNodeIndex
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitMessage, "Su is too scared of ghost, and she won't sleep for 7 days alone."})
    {:noreply, {noOfNodes, nodes}}
  end
end
