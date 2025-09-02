defmodule OMana.Expiry do
  @moduledoc """
  Periodic lazy-expiration sweeper to complement on-read checks.
  """
  alias __MODULE__, as: Expiry

  use GenServer

  def start_link(opts), do: GenServer.start_link(Expiry, opts, name: Expiry)

  @impl true
  def init(opts) do
    storage = Keyword.fetch!(opts, :storage)
    state = %{storage: storage, interval: 1000}
    Process.send_after(self(), :tick, state.interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, %{storage: storage, interval: i} = state) do
    _ = apply(storage, :sweep_expired, [])
    Process.send_after(self(), :tick, i)
    {:noreply, state}
  end
end
