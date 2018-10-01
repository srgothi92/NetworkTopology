defmodule PRJ2.NodeGossip do
  use GenServer
  require Logger

  @moduledoc """
  Node of the topology for Gossip algorithm.
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
    state = init_state(inputs)
    {:ok, state}
  end

  @doc """
  Initiates the message to empty string.
  Returns `{msg, neighbours, count}`
  """
  def init_state(inputs) do
    msg = ""
    neighbours = elem(inputs, 0) || []
    count = 0
    {msg, neighbours, count}
  end

  @doc """
  Updates the neighbours of Node.
  """
  def handle_cast({:updateNeighbours, newNeighbour}, {msg, _, count}) do
    {:noreply, {msg, newNeighbour, count}}
  end

  @doc """
  Handles the spreading of rumours across neighbours.
  """
  def handle_cast({:transmitMessage, message}, {msg, neighbours, count}) do
    if(msg != message) do
      Process.send_after(self(), :spreadRumor, 10)
    end
    {:noreply, {message, neighbours, count}}
  end

  @doc """
  Finds a random neighbour and sends message to it.
  Continues to spreadmessage until count reaches 15.
  """
  def handle_info(:spreadRumor, {message, neighbours, count}) do
    count =
      if count < 15 do
        randNeighInd = :rand.uniform(length(neighbours))
        GenServer.cast(Enum.at(neighbours, randNeighInd - 1), {:transmitMessage, message})
        Process.send_after(self(), :spreadRumor, 10)
        count + 1
      else
        GenServer.cast(:genMain, {:notify, self()})
        15
      end
    {:noreply, {message, neighbours, count}}
  end
end
