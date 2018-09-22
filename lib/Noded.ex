defmodule PRJ2.Noded do
  use GenServer

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
      neighbours = {}
      {s,w,neighbours}
  end
end