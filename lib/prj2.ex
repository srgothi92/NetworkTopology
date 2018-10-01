defmodule PRJ2.Main do
  use GenServer
  require Logger
  use Tensor

  @moduledoc """
  Creates topology, finds and updates the neighbours of each node.
  Transmits message or s,w based on the type of algorithm to random neighbours.
  """
  @doc """
  Starts the GenServer.
  """
  def start_link(topology, noOfNodes, bonus \\ false) do
    GenServer.start_link(__MODULE__, {topology, noOfNodes, bonus}, name: :genMain)
  end

  @doc """
  Initiates the state of the GenServer.
  """
  def init(inputs) do
    state = init_state(inputs)
    {:ok, state}
  end

  defp init_state(inputs) do
    topology = elem(inputs, 0) || "full"
    noOfNodes = elem(inputs, 1) || 5
    nodes = {}
    bonus = elem(inputs, 2)
    completedNodes = %{}
    startTime = 0
    {topology, noOfNodes, nodes, completedNodes, startTime}
  end

  defp nodeMatrixFor3d(first, last, size, nodes, acc, n) when last < n * size * size do
    vec =
      Enum.reduce(first..last, [], fn index, vector ->
        vector = vector ++ [elem(nodes, index)]
      end)

    acc = acc ++ [vec]
    first = last + 1
    last = last + size
    nodeMatrixFor3d(first, last, size, nodes, acc, n)
  end

  defp nodeMatrixFor3d(_, _, _, _, acc, _) do
    acc
  end

  defp combinedMatrixFor3d(size, nodes) do
    Enum.reduce(0..(size - 1), [], fn index, tensor3d ->
      first = index * size * size
      last = first + (size - 1)
      tensor3d = tensor3d ++ [nodeMatrixFor3d(first, last, size, nodes, [], index + 1)]
    end)
  end

  defp preprocessing(noOfNodes, nodes, topology) do
    case topology do
      "rand2d" ->
        nodePositions =
          Enum.reduce(0..(noOfNodes - 1), [], fn _, acc ->
            acc = [{:rand.uniform(), :rand.uniform()}] ++ acc
          end)

        {nodePositions, noOfNodes}

      "3dGrid" ->
        size = Kernel.trunc(:math.pow(noOfNodes, 1 / 3))
        nodePositions = Tensor.new(combinedMatrixFor3d(size, nodes))
        {nodePositions, size * size * size}

      "sphere" ->
        size = Kernel.trunc(:math.sqrt(noOfNodes))

        nodePositions =
          Enum.reduce(0..(size - 1), {}, fn i, acc ->
            Tuple.append(acc, sphereColumn(nodes, i * size, size))
          end)

        {nodePositions, size * size}

      _ ->
        {[], noOfNodes}
    end
  end

  defp findNeighbours(index, nodes, topology, noOfNodes, nodeCoordinates) do
      case topology do
        "line" ->
          cond do
            index == 0 ->
              [elem(nodes, index + 1)]

            index == noOfNodes - 1 ->
              [elem(nodes, index - 1)]

            true ->
              [elem(nodes, index + 1), elem(nodes, index - 1)]
          end

        "full" ->
          nodeList = Tuple.to_list(nodes)
          List.delete_at(nodeList, index)

        "rand2d" ->
          currentNodeCoordinate = Enum.at(nodeCoordinates, index)

          neighbours =
            Enum.reduce(nodeCoordinates, {0, []}, fn iteratingNode, acc ->
              dist =
                :math.sqrt(
                  :math.pow(elem(currentNodeCoordinate, 1) - elem(iteratingNode, 1), 2) +
                    :math.pow(elem(currentNodeCoordinate, 0) - elem(iteratingNode, 0), 2)
                )

              index = elem(acc, 0)
              listNeigh = elem(acc, 1)

              listNeigh =
                if dist < 0.1 do
                  listNeigh ++ [elem(nodes, index)]
                else
                  listNeigh
                end

              acc = {index + 1, listNeigh}
            end)

          elem(neighbours, 1)

        "impline" ->
          index1 = :rand.uniform(noOfNodes) - 1
          [elem(nodes, index1)]

        "3dGrid" ->
          neighbours = []
          size = Kernel.trunc(:math.pow(noOfNodes, 1 / 3))
          x = rem(div(index, size), size)
          y = rem(index, size)
          z = div(index, size * size)

          neighbours =
            if x + 1 < size do
              neighbours ++ [nodeCoordinates[x + 1][y][z]]
            else
              neighbours
            end

          neighbours =
            if(y + 1 < size) do
              neighbours ++ [nodeCoordinates[x][y + 1][z]]
            else
              neighbours
            end

          neighbours =
            if(z + 1 < size) do
              neighbours ++ [nodeCoordinates[x][y][z + 1]]
            else
              neighbours
            end

          neighbours =
            if(x - 1 >= 0) do
              neighbours ++ [nodeCoordinates[x - 1][y][z]]
            else
              neighbours
            end

          neighbours =
            if(y - 1 >= 0) do
              neighbours ++ [nodeCoordinates[x][y - 1][z]]
            else
              neighbours
            end

          neighbours =
            if(z - 1 >= 0) do
              neighbours ++ [nodeCoordinates[x][y][z - 1]]
            else
              neighbours
            end

          neighbours

        "sphere" ->
          neighbours = []
          size = Kernel.trunc(:math.sqrt(noOfNodes))
          row = div(index, size)
          col = rem(index, size)
          neighbours = neighbours ++ [elem(elem(nodeCoordinates, rem(row + size - 1, size)), col)]
          neighbours = neighbours ++ [elem(elem(nodeCoordinates, row), rem(col + size - 1, size))]
          neighbours = neighbours ++ [elem(elem(nodeCoordinates, rem(row + 1, size)), col)]
          neighbours = neighbours ++ [elem(elem(nodeCoordinates, row), rem(col + 1, size))]
          neighbours
      end
  end

  defp createTopology(topology, noOfNodes, nodes, algorithm) do
    # Reset the nodes array if previously created
    if tuple_size(nodes) > 0 do
      stopNodes(nodes, 0, noOfNodes)
    end

    nodes = {}
    nodes =
      if algorithm == "Gossip" do
        createNodesGossip(noOfNodes)
      else
        createNodesPushSum(noOfNodes)
      end
      Logger.info("Nodes Created")

    data = preprocessing(noOfNodes, nodes, topology)
    nodePositions = elem(data, 0)
    noOfNodes = elem(data, 1)

    _ =
      Enum.each(0..(noOfNodes - 1), fn index ->
        GenServer.cast(
          elem(nodes, index),
          {:updateNeighbours, findNeighbours(index, nodes, topology, noOfNodes, nodePositions)}
        )
      end)

    {nodes, noOfNodes}
  end

  defp startNodeGossip(acc) do
    newNode = PRJ2.NodeGossip.start_link({[]})
    Tuple.append(acc, elem(newNode, 1))
  end

  defp createNodesGossip(noOfNodes) do
    Enum.reduce(0..(noOfNodes-1), {}, fn _Y, acc -> startNodeGossip(acc) end)
  end

  defp sphereColumn(nodes, index, size) do
    Enum.reduce(index..(index + size - 1), {}, fn i, acc ->
      acc = Tuple.append(acc, elem(nodes, i))
    end)
  end

  @doc """
  Creates topology and starts the gossip algorithm.
  Prints the time taken to create the topology.
  Transmits message to random neighbours.
  """
  def handle_cast({:startGossip, msg}, {topology, noOfNodes, nodes, completedNodes, _}) do
    startTopologyCreation = System.monotonic_time(:microsecond)
    topologyData = createTopology(topology, noOfNodes, nodes, "Gossip")
    nodes = elem(topologyData, 0)
    noOfNodes = elem(topologyData, 1)
    topologyCreationTime = System.monotonic_time(:microsecond) - startTopologyCreation
    Logger.info("Time to create Topology: #{inspect(topologyCreationTime)}microseconds")
    startGossip = System.monotonic_time(:microsecond)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitMessage, msg})
    {:noreply, {topology, noOfNodes, nodes, completedNodes, startGossip}}
  end

  @doc """
  Starts node for Push-Sum algorithm.
  """
  def startNodePushSum(acc, index) do
    newNode = PRJ2.NodePushSum.start_link({index + 1, 1})
    Tuple.append(acc, elem(newNode, 1))
  end

  @doc """
  Creates node for Push-Sum algorithm.
  """
  def createNodesPushSum(noOfNodes) do
    Enum.reduce(0..(noOfNodes-1), {}, fn n, acc -> startNodePushSum(acc, n) end)
  end

  @doc """
  Creates topology and starts the Push-Sum algorithm.
  Prints the time taken to create the topology.
  Transmits s and w to random neighbour.
  """
  def handle_cast({:startPushSum, s, w}, {topology, noOfNodes, nodes, completedNodes, _}) do
    startTopologyCreation = System.monotonic_time(:microsecond)
    topologyData = createTopology(topology, noOfNodes, nodes, "PushSum")
    nodes = elem(topologyData, 0)
    noOfNodes = elem(topologyData, 1)
    topologyCreationTime = System.monotonic_time(:microsecond) - startTopologyCreation
    Logger.info("Time to create Topology: #{inspect(topologyCreationTime)}microseconds")
    startTimePushSum = System.monotonic_time(:microsecond)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitSum, {s, w}})
    {:noreply, {topology, noOfNodes, nodes, completedNodes, startTimePushSum}}
  end

  @doc """
  Checks if all the nodes are converged in Gossip algorithm and terminates it.
  Prints the time taken to complete the algorithm.
  """
  def handle_cast({:notify, nodePid}, {topology, noOfNodes, nodes, completedNodes, startTime}) do
    completedNodes = Map.put(completedNodes, nodePid, true)

    if map_size(completedNodes) == noOfNodes do
      timeGossip = System.monotonic_time(:microsecond) - startTime
      Logger.info("Gossip algorithm completed in time #{inspect(timeGossip)}microSeconds")
    end

    {:noreply, {topology, noOfNodes, nodes, completedNodes, startTime}}
  end

  @doc """
  Terminates Push-Sum algorithm.
  Prints the time taken to complete the Push-Sum algorithm and the average value.
  """
  def handle_cast(
        {:terminatePushSum, nodePid, avg},
        {topology, noOfNodes, nodes, completedNodes, startTime}
      ) do
    # completedNodes = Map.put(completedNodes,nodePid,true)
    # if(Process.alive?(nodePid)) do
    #   GenServer.stop(nodePid,:normal)
    # end
    # if map_size(completedNodes) == noOfNodes do
    stopNodes(nodes, 0, noOfNodes)
    timePushSum = System.monotonic_time(:microsecond) - startTime

    Logger.info(
      "PushSum algorithm completed in time #{inspect(timePushSum)}microSeconds and with average value #{
        inspect(avg)
      }"
    )

    # end
    {:noreply, {topology, noOfNodes, nodes, completedNodes, startTime}}
  end

  @doc """
  Stops a single node at given index.
  """
  def stopNode(nodes, index) do
    GenServer.stop(elem(nodes, index), :normal)
  end

  @doc """
  Stops all the nodes.
  """
  def stopNodes(nodes, index, size) do

    if index < size && Process.alive?(elem(nodes, index)) do
      nodePid = elem(nodes, index)
      GenServer.stop(nodePid, :normal)
      stopNodes(nodes, index + 1, size)
    end
  end
end
