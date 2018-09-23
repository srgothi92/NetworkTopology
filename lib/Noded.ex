defmodule PRJ2.Noded do
  use GenServer
  require Logger

  def start_link(opts) do
      GenServer.start_link(__MODULE__, :ok, opts)
  end

   def init(:ok) do
      state = init_state()
      {:ok,state}
  end

  def init_state() do
      s = 0
      w = 0
      neighbours = []
      {s,w,neighbours}
  end

  def handle_cast({:updateNeighbours,newNeighbour},{s,w,_}) do
    {:noreply,{s,w,newNeighbour}}
  end

  def handle_cast({:transmitMessage,message},{s,w,neighbours}) do
    w =if w<15 do
        Logger.info "Node  #{inspect(self())} w #{inspect(w)}neighbours #{inspect(neighbours)}"
        Enum.each(neighbours, fn(x) -> GenServer.cast(x,{:transmitMessage,message}) end)
        w+1
    else
      Logger.info "Node Converged #{inspect(self())}"
      GenServer.cast(:genMain, {:notify, self()})
      10
    end

    {:noreply,{s,w,neighbours}}
  end

  def handle_call(:getstate,_from,state) do
    {:reply,state,state}
  end

end
