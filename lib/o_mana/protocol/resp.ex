defmodule OMana.Protocol.RESP do
  @moduledoc """
  Minimal RESP2 parser/encoder supporting Arrays, Bulk Strings, Simple Strings, Integers, Errors.
  The server expects requests as Arrays of Bulk Strings (what redis-cli sends).
  """

  @crlf "\r\n"

  @doc """
  Parse as many frames as possible from a buffer. Returns {frames, rest}.
  Frames for requests are decoded as lists of binaries (argv).
  """
  def parse_many(buffer) when is_binary(buffer), do: do_parse_many(buffer, [])

  defp do_parse_many(buffer, acc) do
    case parse_one(buffer) do
      {:ok, frame, rest} -> do_parse_many(rest, [frame | acc])
      :more -> {Enum.reverse(acc), buffer}
      {:error, _} -> {Enum.reverse(acc), buffer}
    end
  end

  @doc """
  Encode server replies from internal representation:
  - {:ok, "OK"} -> "+OK\r\n"
  - {:error, msg} -> "-ERR msg\r\n"
  - {:int, n} or integer -> ":n\r\n"
  - nil -> "$-1\r\n" (null bulk)
  - binary/string -> bulk string
  - {:array, list} -> array of bulk strings/integers/nils
  """
  def encode({:ok, "OK"}), do: "+OK" <> @crlf
  def encode({:ok, msg}) when is_binary(msg), do: "+" <> msg <> @crlf
  def encode({:error, msg}) when is_binary(msg), do: "-" <> msg <> @crlf
  def encode({:int, n}) when is_integer(n), do: ":#{n}" <> @crlf
  def encode(n) when is_integer(n), do: ":#{n}" <> @crlf
  def encode(nil), do: "$-1" <> @crlf
  def encode(bin) when is_binary(bin), do: "$#{byte_size(bin)}" <> @crlf <> bin <> @crlf
  def encode(list) when is_list(list), do: encode({:array, list})

  def encode({:array, list}) when is_list(list) do
    inner =
      Enum.map_join(list, fn
        nil -> "$-1" <> @crlf
        i when is_integer(i) -> ":#{i}" <> @crlf
        {:int, i} -> ":#{i}" <> @crlf
        {:error, msg} -> "-" <> msg <> @crlf
        {:ok, msg} -> "+" <> msg <> @crlf
        bin when is_binary(bin) -> "$#{byte_size(bin)}" <> @crlf <> bin <> @crlf
      end)

    "*#{length(list)}" <> @crlf <> inner
  end

  defp parse_one(<<"*", rest::binary>>) do
    with {n, rest1} <- take_int(rest),
         {elems, rest2} <- parse_n_bulk(n, rest1) do
      {:ok, elems, rest2}
    else
      :more -> :more
      _ -> {:error, :bad_array}
    end
  end

  defp parse_one(_other), do: :more

  defp parse_n_bulk(0, rest), do: {[], rest}

  defp parse_n_bulk(n, <<"$", rest::binary>>) when n > 0 do
    with {len, rest1} <- take_int(rest),
         true <- len >= 0,
         <<bin::binary-size(len), "\r\n", rest2::binary>> <- rest1 do
      {tail, rest3} = parse_n_bulk(n - 1, rest2)
      {[bin | tail], rest3}
    else
      :more -> :more
      _ -> {:error, :bad_bulk}
    end
  end

  defp parse_n_bulk(_n, _rest), do: {:error, :bad_bulk}

  defp take_int(bin) do
    case :binary.match(bin, @crlf) do
      {idx, 2} ->
        <<digits::binary-size(idx), "\r\n", rest::binary>> = bin

        case Integer.parse(digits) do
          {n, ""} -> {n, rest}
          _ -> {:error, :bad_int}
        end

      :nomatch ->
        :more
    end
  end
end
