defmodule PRJ2.NodePushSum do
  use GenServer
  require Logger

  @moduledoc """
  Node of the topology for Push-Sum algorithm.
  """
  @doc """
  Starts the GenServer.
  """
  def start_link(inputs) do
    GenServer.start_link(__MODULE__, inputs)
  end

  @doc """
  Initiates the state of the GenServer.
  """
  def init(inputs) do
    Process.flag(:trap_exit, true)
    state = init_state(inputs)
    {:ok, state}
  end

  @doc """
  Returns `{s,w,neighbours,count}`
  """
  def init_state(inputs) do
    s = elem(inputs, 0) || 0
    w = elem(inputs, 1) || 0
    neighbours = []
    count = 0;
    {s, w, neighbours,count}
  end

  @doc """
  Update the neighbour of Node
  """
  def handle_cast({:updateNeighbours, newNeighbour}, {s, w, _, count}) do
    {:noreply, {s, w, newNeighbour,count}}
  end

  @doc """
  Calculates the s and w value and forwards to a random node.
  Terminates the transmission if the ratio of s/w does not change
  more than pow(10,-10) for 3 consecutive rounds.
  """
  def handle_cast({:transmitSum, {incomingS, incomingW}}, {s,w,neighbours, count}) do
    newS = s + incomingS
    newW = w + incomingW
    delta = abs(newS/newW - (s/w))
    if(delta < :math.pow(10,-10) && count>=3) do
      GenServer.cast(:genMain, {:terminatePushSum, self(),s/w})
      {:noreply, {newS/2, newW/2, neighbours, count}}
    end
    count = if(delta < :math.pow(10,-10) && count < 3) do
      count + 1
    end
    count = if(delta > :math.pow(10,-10)) do
      0
    end
    node = findLiveRandNeig(neighbours)
    # Forwarding Sum to a random node
    GenServer.cast(node, {:transmitSum, {newS/2,newW/2}})
    {:noreply, {newS/2, newW/2, neighbours, count}}
  end

  defp findLiveRandNeig(neighbours) do
    randNeighInd = :rand.uniform(length(neighbours))
    node = Enum.at(neighbours, randNeighInd-1)
    if(Process.alive?(node)) do
      node
    else
      findLiveRandNeig(neighbours)
    end
  end
end
