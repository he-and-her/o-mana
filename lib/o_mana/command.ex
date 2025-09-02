defmodule OMana.Command do
  @moduledoc """
  Command dispatch. Each command is a pure function over a `storage` module.
  The command plane depends only on the storage behaviour — not ETS, not TCP, not RESP.
  """

  alias OMana.Storage

  @type argv :: [binary()]

  @spec dispatch(module(), argv) :: term()
  def dispatch(storage, [cmd | rest]) do
    case String.upcase(cmd) do
      "PING" -> ping(rest)
      "ECHO" -> echo(rest)
      "SET" -> set(storage, rest)
      "GET" -> get(storage, rest)
      "DEL" -> del(storage, rest)
      "INCR" -> incr(storage, rest)
      "EXPIRE" -> expire(storage, rest)
      "TTL" -> ttl(storage, rest)
      other -> {:error, "ERR unknown command '#{other}'"}
    end
  end

  def dispatch(_storage, _), do: {:error, "ERR empty command"}

  defp ping([]), do: {:ok, "PONG"}
  defp ping([msg]), do: msg
  defp ping(_), do: {:error, "ERR wrong number of arguments for 'ping'"}

  defp echo([msg]), do: msg
  defp echo(_), do: {:error, "ERR wrong number of arguments for 'echo'"}

  defp get(storage, [key]) do
    case Storage.get(storage, key) do
      :not_found -> nil
      {:ok, v} -> v
    end
  end

  defp get(_storage, _), do: {:error, "ERR wrong number of arguments for 'get'"}

  defp set(storage, [key, value | opts]) do
    {ex, mode} = parse_set_opts(opts)

    with {:ok, exists?} <- Storage.exists?(storage, key),
         :ok <- check_mode(exists?, mode),
         :ok <- Storage.put(storage, key, value),
         :ok <- maybe_expire(storage, key, ex) do
      {:ok, "OK"}
    else
      :skip -> nil
      {:error, msg} -> {:error, msg}
    end
  end

  defp set(_storage, _), do: {:error, "ERR wrong number of arguments for 'set'"}

  defp parse_set_opts(opts) do
    Enum.reduce(opts, {nil, :any}, fn opt, {ex, mode} ->
      up = String.upcase(opt)

      case {up, ex, mode} do
        {"EX", nil, _} -> {"EX", mode}
        {sec, "EX", _} -> {String.to_integer(sec), mode}
        {"NX", _, _} -> {ex, :nx}
        {"XX", _, _} -> {ex, :xx}
        _ -> {ex, mode}
      end
    end)
    |> then(fn
      {secs, mode} when is_integer(secs) -> {secs, mode}
      {_, mode} -> {nil, mode}
    end)
  end

  defp check_mode(false, :xx), do: :skip
  defp check_mode(true, :nx), do: :skip
  defp check_mode(_, _), do: :ok

  defp maybe_expire(_storage, _key, nil), do: :ok
  defp maybe_expire(storage, key, secs), do: Storage.expire(storage, key, secs)

  defp del(storage, keys) when length(keys) > 0 do
    {:int, Storage.del_many(storage, keys)}
  end

  defp del(_storage, _), do: {:error, "ERR wrong number of arguments for 'del'"}

  defp incr(storage, [key]) do
    case Storage.get(storage, key) do
      :not_found ->
        :ok = Storage.put(storage, key, "0")
        incr(storage, [key])

      {:ok, v} ->
        case Integer.parse(v) do
          {n, ""} ->
            n = n + 1
            :ok = Storage.put(storage, key, Integer.to_string(n))
            {:int, n}

          _ ->
            {:error, "ERR value is not an integer or out of range"}
        end
    end
  end

  defp incr(_storage, _), do: {:error, "ERR wrong number of arguments for 'incr'"}

  defp expire(storage, [key, sec]) do
    secs = String.to_integer(sec)

    case Storage.expire(storage, key, secs) do
      :ok -> {:int, 1}
      :not_found -> {:int, 0}
    end
  end

  defp expire(_storage, _), do: {:error, "ERR wrong number of arguments for 'expire'"}

  defp ttl(storage, [key]) do
    case Storage.ttl(storage, key) do
      :not_found -> {:int, -2}
      :no_expiry -> {:int, -1}
      {:ok, secs} -> {:int, secs}
    end
  end

  defp ttl(_storage, _), do: {:error, "ERR wrong number of arguments for 'ttl'"}
end
