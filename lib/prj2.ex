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

  def findNeighbours(index, nodes, topology,noOfNodes,nodeCoordinates) do
    su = case topology do
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
      "3dmatrix" ->
        Graphmath.Vec3.create()

      end
      IO.inspect su
      su

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
    topology = "impline";
    nodeCoordinates = if topology == "rand2d" do
      Enum.reduce(0..(noOfNodes-1), [],fn index,acc -> acc = [{:rand.uniform(),:rand.uniform()}] ++ acc end)
    else
      []
    end
    Enum.each(0..(noOfNodes-1), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, topology,noOfNodes,nodeCoordinates)}) end)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
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
    topology = "rand2d";
    nodeCoordinates = if topology == "rand2d" do
      Enum.reduce(0..(noOfNodes-1), [],fn index,acc -> acc = [{:rand.uniform(),:rand.uniform()}] ++ acc end)
    end
    Enum.each(0..(noOfNodes - 1), fn index -> GenServer.cast(elem(nodes,index), {:updateNeighbours, findNeighbours(index, nodes, "full",noOfNodes,nodeCoordinates)}) end)
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

  def handle_call({:terminatePushSum, avg}, _, {noOfNodes, nodes, completedNodes}) do
    stopNodes(nodes, 0, noOfNodes)
    Logger.info("PushSum algorithm completed with average value #{inspect(avg)}")
    {:noreply,{noOfNodes, nodes, completedNodes} }
  end

  def stopNodes(nodes, index, size) do
    if index != size-1 do
      GenServer.stop(elem(nodes,index),"Converged")
      stopNodes(nodes, index+1, size)
    end
  end

  def handle_call(:getstate,_from,state) do
    {:reply,state,state}
  end

  def nodeMatrixFor3d(first,last,size,nodes,acc,n) when last<=(n*size*size) do
    IO.inspect n
    IO.inspect first
    IO.inspect last
    vec = Enum.reduce(first..last, [], fn index,vector ->
      vector = vector ++ [elem(nodes,index)] 
      end)
    acc = acc ++ [vec]
    first = last+1
    last = last+size
    nodeMatrixFor3d(first,last,size,nodes,acc,n) 
  end

  def nodeMatrixFor3d(first,last,size,nodes,acc,n) do
    acc
  end

  def combinedMatrixFor3d(size,nodes) do 
    Enum.reduce(0..(size-1),[], fn index,tensor3d ->
      first = index*size*size
      last = first+(size-1)
      tensor3d = tensor3d ++ [nodeMatrixFor3d(first,last,size,nodes,tensor3d,index+1)] 
    end)
  end

  
end
