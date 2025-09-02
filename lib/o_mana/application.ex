defmodule OMana.Application do
  @moduledoc false
  use Application

  @default_port 6380

  def start(_type, _args) do
    children = [
      {OMana.Storage.ETS, name: OMana.Storage},
      {OMana.Expiry, storage: OMana.Storage},
      {Task.Supervisor, name: OMana.ConnSupervisor},
      {OMana.Server, port: @default_port, storage: OMana.Storage}
    ]

    opts = [strategy: :one_for_one, name: OMana.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
