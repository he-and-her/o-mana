defmodule OMana do
  @moduledoc """
  Public, protocol-agnostic API over the orthogonal planes.
  This is convenient for unit tests and future extension (HTTP, gRPC, etc.).
  """

  alias OMana.Command

  @type ok :: :ok
  @type err :: {:error, String.t()}

  def call(storage, argv) when is_list(argv) do
    Command.dispatch(storage, argv)
  end
end
