defmodule OMana.Connection do
  @moduledoc false

  alias OMana.Command
  alias OMana.Protocol.RESP

  @spec loop(port(), module()) :: :ok
  def loop(sock, storage) do
    buffer = ""

    case recv(sock) do
      {:ok, data} ->
        buffer = buffer <> data
        {frames, rest} = RESP.parse_many(buffer)

        Enum.each(frames, fn
          argv when is_list(argv) ->
            reply = Command.dispatch(storage, argv)
            :ok = :gen_tcp.send(sock, RESP.encode(reply))

          other ->
            :ok =
              :gen_tcp.send(sock, RESP.encode({:error, "ERR protocol error: #{inspect(other)}"}))
        end)

        loop_with(sock, storage, rest)

      {:closed, _} ->
        :ok

      {:error, _} ->
        :ok
    end
  end

  defp loop_with(sock, storage, buffer) do
    case recv(sock) do
      {:ok, data} ->
        buffer = buffer <> data
        {frames, rest} = OMana.Protocol.RESP.parse_many(buffer)

        Enum.each(frames, fn argv ->
          reply = OMana.Command.dispatch(storage, argv)
          :ok = :gen_tcp.send(sock, OMana.Protocol.RESP.encode(reply))
        end)

        loop_with(sock, storage, rest)

      {:closed, _} ->
        :ok

      {:error, _} ->
        :ok
    end
  end

  defp recv(sock), do: :gen_tcp.recv(sock, 0)
end
