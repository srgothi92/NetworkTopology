defmodule PRJ2.Main do
  use GenServer
  require Logger
  use Tensor

  @moduledoc """
  Creates topology and Transmits message or s,w
  based on the type of algorithm to random neighbours.
  """
  @doc """
  Starts the GenServer.
  """
  def start_link(topology, noOfNodes, bonus \\ false, nodesToKill \\ 10, timeInterval \\ 100) do
    GenServer.start_link(__MODULE__, {topology, noOfNodes, bonus, nodesToKill, timeInterval},
      name: :genMain
    )
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
    nodesToKill = elem(inputs, 3)
    timeInterval = elem(inputs, 4)
    completedNodes = %{}
    startTime = 0
    {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill, timeInterval}
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
        # Arrange nodes by assigning random x and y co-ordiates between 0 and 1
        nodePositions =
          Enum.reduce(0..(noOfNodes - 1), [], fn _, acc ->
            acc = [{:rand.uniform(), :rand.uniform()}] ++ acc
          end)

        {nodePositions, noOfNodes}

      "3dGrid" ->
        # Arrange Nodes in the form of Tensor or 3d Grid
        size = Kernel.trunc(:math.pow(noOfNodes, 1 / 3))
        nodePositions = Tensor.new(combinedMatrixFor3d(size, nodes))
        {nodePositions, size * size * size}

      "sphere" ->
        # Arrange Nodes in the for of Matrix or 2d Grid
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
        # Retun the previous and next node from the node list as its neighbour except on the borders
        cond do
          index == 0 ->
            [elem(nodes, index + 1)]

          index == noOfNodes - 1 ->
            [elem(nodes, index - 1)]

          true ->
            [elem(nodes, index + 1), elem(nodes, index - 1)]
        end

      "full" ->
        # Delete itself from the node List to find its neighbours
        nodeList = Tuple.to_list(nodes)
        List.delete_at(nodeList, index)

      "rand2d" ->
        # Find all the neighbours using the condition of distance < 0.1
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
        cond do
          index == noOfNodes - 1 ->
            randIndex = :rand.uniform(noOfNodes) - 1
            [elem(nodes, randIndex), elem(nodes, 0)]

          true ->
            randIndex = :rand.uniform(noOfNodes) - 1
            [elem(nodes, randIndex), elem(nodes, index + 1)]
        end

      "3dGrid" ->
        # Find the negibours from the Nodes arranged in 3dGrid form
        neighbours = []
        size = Kernel.trunc(:math.pow(noOfNodes + 1, 1 / 3))
        # Co ordinate of Node at index in the 3d Grid
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
        # Find the negibours from the Nodes arranged in Matrix form
        neighbours = []
        size = Kernel.trunc(:math.sqrt(noOfNodes + 1))
        # Co-ordinates of Node at index in 2d Matrix
        row = div(index, size)
        col = rem(index, size)
        neighbours = neighbours ++ [elem(elem(nodeCoordinates, rem(row + size - 1, size)), col)]
        neighbours = neighbours ++ [elem(elem(nodeCoordinates, row), rem(col + size - 1, size))]
        neighbours = neighbours ++ [elem(elem(nodeCoordinates, rem(row + 1, size)), col)]
        neighbours = neighbours ++ [elem(elem(nodeCoordinates, row), rem(col + 1, size))]
        neighbours
    end
  end

  @doc """
  Creates topology with the given input of topology- {"line","full", "3dGrid", "rand2d", "sphere", "impline"}
  Number of Nodes, Nodes List and type of algortihm {"Gossip", "PushSum"}
  """
  def createTopology(topology, noOfNodes, nodes, algorithm) do
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
    Enum.reduce(0..(noOfNodes - 1), {}, fn _Y, acc -> startNodeGossip(acc) end)
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
  def handle_cast(
        {:startGossip, msg},
        {topology, noOfNodes, nodes, completedNodes, _, bonus, nodesToKill, timeInterval}
      ) do
    startTopologyCreation = System.monotonic_time(:microsecond)
    topologyData = createTopology(topology, noOfNodes, nodes, "Gossip")
    nodes = elem(topologyData, 0)
    noOfNodes = elem(topologyData, 1)
    topologyCreationTime = System.monotonic_time(:microsecond) - startTopologyCreation
    Logger.info("Time to create Topology: #{inspect(topologyCreationTime)}microseconds")
    startGossip = System.monotonic_time(:microsecond)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitMessage, msg})

    if bonus == true do
      Process.send_after(self(), :killRandomNode, timeInterval)
    end

    {:noreply,
     {topology, noOfNodes, nodes, completedNodes, startGossip, bonus, nodesToKill, timeInterval}}
  end

  @doc """
  Starts node for Push-Sum algorithm.
  """
  defp startNodePushSum(acc, index) do
    newNode = PRJ2.NodePushSum.start_link({index + 1, 1})
    Tuple.append(acc, elem(newNode, 1))
  end

  @doc """
  Creates node for Push-Sum algorithm.
  """
  defp createNodesPushSum(noOfNodes) do
    Enum.reduce(0..(noOfNodes - 1), {}, fn n, acc -> startNodePushSum(acc, n) end)
  end

  @doc """
  Creates topology and starts the Push-Sum algorithm.
  Prints the time taken to create the topology.
  Transmits s and w to random neighbour.
  """
  def handle_cast(
        {:startPushSum, s, w},
        {topology, noOfNodes, nodes, completedNodes, _, bonus, nodesToKill, timeInterval}
      ) do
    startTopologyCreation = System.monotonic_time(:microsecond)
    topologyData = createTopology(topology, noOfNodes, nodes, "PushSum")
    nodes = elem(topologyData, 0)
    noOfNodes = elem(topologyData, 1)
    topologyCreationTime = System.monotonic_time(:microsecond) - startTopologyCreation
    Logger.info("Time to create Topology: #{inspect(topologyCreationTime)}microseconds")
    startTimePushSum = System.monotonic_time(:microsecond)
    randNodeIndex = :rand.uniform(noOfNodes) - 1
    GenServer.cast(elem(nodes, randNodeIndex), {:transmitSum, {s, w}})

    if bonus == true do
      Process.send_after(self(), :killRandomNode, timeInterval)
    end

    {:noreply,
     {topology, noOfNodes, nodes, completedNodes, startTimePushSum, bonus, nodesToKill,
      timeInterval}}
  end

  @doc """
  Checks if all the nodes are converged in Gossip algorithm and terminates it.
  Prints the time taken to complete the algorithm.
  """
  def handle_cast(
        {:notify, nodePid},
        {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill, timeInterval}
      ) do
    completedNodes = Map.put(completedNodes, nodePid, true)

    nodesToKill =
      if map_size(completedNodes) == noOfNodes do
        timeGossip = System.monotonic_time(:microsecond) - startTime
        Logger.info("Gossip algorithm completed in time #{inspect(timeGossip)}microSeconds")
        0
      else
        nodesToKill
      end

    {:noreply,
     {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill, timeInterval}}
  end

  @doc """
  Terminates Push-Sum algorithm.
  Prints the time taken to complete the Push-Sum algorithm and the average value.
  """
  def handle_cast(
        {:terminatePushSum, nodePid, avg},
        {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill, timeInterval}
      ) do
    stopNodes(nodes, 0, noOfNodes)
    timePushSum = System.monotonic_time(:microsecond) - startTime

    Logger.info(
      "PushSum algorithm completed in time #{inspect(timePushSum)}microSeconds and with average value #{
        inspect(avg)
      }"
    )

    {:noreply,
     {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill, timeInterval}}
  end

  def handle_info(
        :killRandomNode,
        {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill, timeInterval}
      ) do
    completedNodes =
      if nodesToKill > 0 do
        killdedNodePid = stopRandomNode(nodes, noOfNodes)
        Process.send_after(self(), :killRandomNode, timeInterval)
        # Mark the killed node as completed since it will never converge
        Map.put(completedNodes, killdedNodePid, true)
      end

    {:noreply,
     {topology, noOfNodes, nodes, completedNodes, startTime, bonus, nodesToKill - 1, timeInterval}}
  end

  @doc """
  Stops a single node at random position.
  """
  defp stopRandomNode(nodes, noOfNodes) do
    randNodeIndex = :rand.uniform(noOfNodes) - 1

    if(Process.alive?(elem(nodes, randNodeIndex))) do
      GenServer.stop(elem(nodes, randNodeIndex), :normal)
      Logger.info("Node #{inspect(elem(nodes, randNodeIndex))} killed!")
      elem(nodes, randNodeIndex)
    else
      # Trying utill a node is killed which was alive
      stopRandomNode(nodes, noOfNodes)
    end
  end

  @doc """
  Stops all the nodes.
  """
  defp stopNodes(nodes, index, size) do
    if index < size && Process.alive?(elem(nodes, index)) do
      nodePid = elem(nodes, index)
      GenServer.stop(nodePid, :normal)
      stopNodes(nodes, index + 1, size)
    end
  end
end
