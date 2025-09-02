defmodule OMana.Server do
  @moduledoc """
  Bare-bones TCP server speaking RESP. Each connection handled by a Task.
  """

  alias __MODULE__, as: Server

  require Logger

  use GenServer

  def start_link(opts), do: GenServer.start_link(Server, opts, name: Server)

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    storage = Keyword.fetch!(opts, :storage)

    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    state = %{lsock: socket, storage: storage}

    Logger.info("OMana listening on port #{port}")

    send(self(), :accept)

    {:ok, state}
  end

  @impl true
  def handle_info(:accept, %{lsock: lsock, storage: storage} = state) do
    case :gen_tcp.accept(lsock) do
      {:ok, sock} ->
        {:ok, _pid} =
          Task.Supervisor.start_child(OMana.ConnSupervisor, fn ->
            :ok = :inet.setopts(sock, active: false)
            OMana.Connection.loop(sock, storage)
          end)

        :ok = :gen_tcp.controlling_process(sock, Process.whereis(OMana.ConnSupervisor))
        send(self(), :accept)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("accept failed: #{inspect(reason)}")

        {:stop, reason, state}
    end
  end
end
