defmodule PRJ2.NodePushSum do
  use GenServer
  require Logger

  def start_link(inputs) do
    GenServer.start_link(__MODULE__, inputs)
  end

  def init(inputs) do
    state = init_state(inputs)
    {:ok, state}
  end

  def init_state(inputs) do
    s = elem(inputs, 0) || 0
    w = elem(inputs, 1) || 0
    neighbours = []
    count = 0;
    {s, w, neighbours,count}
  end

  def handle_cast({:updateNeighbours, newNeighbour}, {s, w, _, count}) do
    {:noreply, {s, w, newNeighbour,count}}
  end

  def handle_cast({:transmitSum, {incomingS, incomingW}}, {s,w,neighbours, count}) do
    newS = s + incomingS
    newW = w + incomingW
    delta = abs(newS/newW - (s/w))
    Logger.info("delta #{inspect(delta)}")
    if(delta < :math.pow(10,-10) && count>=3) do
      Logger.info("Node Converged #{inspect(self())}")
      GenServer.cast(:genMain, {:notify, self()})
      {:stop, "Node Converged", {s,w,neighbours, count}}
      # System.stop(0)
      # GenServer.stop(self(), "Node Converged")
    end
    count = if(delta < :math.pow(10,-10) && count < 3) do
      count + 1
    end
    count = if(delta > :math.pow(10,-10)) do
      0
    end
    randNeighInd = :rand.uniform(length(neighbours))
    GenServer.cast(Enum.at(neighbours, randNeighInd-1), {:transmitSum, {newS/2,newW/2}})
    {:noreply, {newS/2, newW/2, neighbours, count}}
  end

  def handle_call(:getstate, _from, state) do
    {:reply, state, state}
  end
end