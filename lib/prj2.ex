defmodule PRJ2.Main do
  use GenServer
  require Logger
  require Tensor

  @moduledoc """
  Documentation for PRJ2.
  """

  def start_link(topology, noOfNodes) do
    GenServer.start_link(__MODULE__,{topology, noOfNodes},name: :genMain)
  end

  def init(inputs) do
    state = init_state(inputs)
    {:ok, state}
  end

  defp init_state(inputs) do
    topology = elem(inputs,0) || "full"
    noOfNodes = elem(inputs,1) || 5
    nodes = {}
    completedNodes = %{}
    startTime = 0
    {topology, noOfNodes, nodes, completedNodes, startTime}
  end

  defp createTopology(topology, noOfNodes, nodes, algorithm) do
    # Reset the nodes array if previously created
    if tuple_size(nodes) > 0 do
      stopNodes(nodes, 0, noOfNodes)
    end
    nodes = {}
    nodes = if algorithm == "Gossip" do
      createNodesGossip(noOfNodes)
    else
      createNodesPushSum(noOfNodes)
    end
    nodeCoordinates = preprocessing(noOfNodes,nodes, topology)
    _ = Enum.each(0..(noOfNodes - 1), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, "full",noOfNodes,nodeCoordinates)}) end)
    nodes
  end

  defp findNeighbours(index, nodes, topology,noOfNodes,nodeCoordinates) do
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
        nodeList = Tuple.to_list(nodes)
        List.delete_at(nodeList,index)
      "rand2d" ->
        currentNodeCoordinate = Enum.at(nodeCoordinates,index)
        neighbours = Enum.reduce(nodeCoordinates, {0,[]}, fn iteratingNode,acc ->
          dist = :math.sqrt(:math.pow((elem(currentNodeCoordinate,1) - elem(iteratingNode,1)),2) + :math.pow((elem(currentNodeCoordinate,0) - elem(iteratingNode,0)),2));
          index = elem(acc,0)
          listNeigh = elem(acc,1)
          listNeigh = if dist<0.1 do
            listNeigh ++ [elem(nodes,index)]
          else
            listNeigh
          end
          acc = {index+1,listNeigh}
        end)
        elem(neighbours,1)
      "impline" ->
        index1 = :rand.uniform(noOfNodes)-1
        [elem(nodes,index1)]
      "3dGrid" ->
        Graphmath.Vec3.create()

      end
  end

  defp startNodeGossip(acc) do
    newNode = PRJ2.NodeGossip.start_link({[]})
    Tuple.append(acc,elem(newNode,1))
  end

  defp createNodesGossip(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.reduce(list,{}, fn _,acc ->  startNodeGossip(acc) end)
  end

  defp preprocessing(noOfNodes,nodes, topology) do
    case topology do
      "rand2d" ->
        Enum.reduce(0..(noOfNodes-1), [],fn _,acc -> acc = [{:rand.uniform(),:rand.uniform()}] ++ acc end)
      "3dGrid" ->
        Tensor.new(combinedMatrixFor3d(2,nodes))
      _ ->
          []
    end
  end

  def handle_cast({:startGossip, msg}, {topology, noOfNodes, nodes, completedNodes, _}) do
    startTopologyCreation = System.monotonic_time(:microsecond)
    nodes = createTopology(topology, noOfNodes, nodes, "Gossip")
    topologyCreationTime = System.monotonic_time(:microsecond) - startTopologyCreation
    Logger.info("Time to create Topology: #{inspect(topologyCreationTime)}microseconds")
    startGossip = System.monotonic_time(:microsecond)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitMessage, msg})
    {:noreply, {topology, noOfNodes, nodes, completedNodes, startGossip}}
  end

  def startNodePushSum(acc, index) do
    newNode = PRJ2.NodePushSum.start_link({index + 1, 1})
    Tuple.append(acc,elem(newNode,1))
  end

  def createNodesPushSum(noOfNodes) do
    list = 0..(noOfNodes - 1)
    Enum.reduce(list,{}, fn n,acc ->  startNodePushSum(acc, n) end)
  end

  def handle_cast({:startPushSum, s, w}, {topology, noOfNodes, nodes, completedNodes, _}) do
    startTopologyCreation = System.monotonic_time(:microsecond)
    nodes = createTopology(topology, noOfNodes, nodes, "PushSum")
    topologyCreationTime = System.monotonic_time(:microsecond) - startTopologyCreation
    Logger.info("Time to create Topology: #{inspect(topologyCreationTime)}microseconds")
    startTimePushSum = System.monotonic_time(:microsecond)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitSum, {s, w}})
    {:noreply, {topology, noOfNodes, nodes, completedNodes, startTimePushSum}}
  end

  def handle_cast({:notify, nodePid}, {topology, noOfNodes, nodes, completedNodes, startTime}) do
    completedNodes = Map.put(completedNodes,nodePid,true)
    if map_size(completedNodes) == noOfNodes do
      timeGossip = System.monotonic_time(:microsecond) -startTime
      Logger.info("Gossip algorithm completed in time #{inspect(timeGossip)}microSeconds")
    end
    {:noreply,{topology, noOfNodes, nodes, completedNodes, startTime} }
  end

  def handle_cast({:terminatePushSum, nodePid, avg}, {topology, noOfNodes, nodes, completedNodes, startTime}) do
    # completedNodes = Map.put(completedNodes,nodePid,true)
    # if(Process.alive?(nodePid)) do
    #   GenServer.stop(nodePid,:normal)
    # end
    # if map_size(completedNodes) == noOfNodes do
      stopNodes(nodes,0, noOfNodes)
      timePushSum = System.monotonic_time(:microsecond) -startTime
      Logger.info("PushSum algorithm completed in time #{inspect(timePushSum)}microSeconds and with average value #{inspect(avg)}")
    # end
    {:noreply,{topology, noOfNodes, nodes, completedNodes, startTime} }
  end

  def stopNode(nodes, index) do

      GenServer.stop(elem(nodes,index),:normal)
  end

  def stopNodes(nodes, index, size) do
    if index != size-1 do
      GenServer.stop(elem(nodes,index),:normal)
      stopNodes(nodes, index+1, size)
    end
  end

  def nodeMatrixFor3d(first,last,size,nodes,acc,n) when last<(n*size*size) do
    vec = Enum.reduce(first..last, [], fn index,vector ->
      vector = vector ++ [elem(nodes,index)]
      end)
    acc = acc ++ [vec]
    first = last+1
    last = last+size
    nodeMatrixFor3d(first,last,size,nodes,acc,n)
  end

  def nodeMatrixFor3d(_,_,_,_,acc,_) do
    acc
  end

  def combinedMatrixFor3d(size,nodes) do
    Enum.reduce(0..(size-1),[], fn index,tensor3d ->
      first = index*size*size
      last = first+(size-1)
      tensor3d = tensor3d ++ [nodeMatrixFor3d(first,last,size,nodes,[],index+1)]
    end)
  end
end
