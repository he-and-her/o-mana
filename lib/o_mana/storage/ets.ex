defmodule OMana.Storage.ETS do
  @moduledoc """
  ETS-backed storage engine (orthogonal to command/protocol/network).
  Keys and values are binaries. Expiry managed via a companion table and a sweeper GenServer.
  """
  alias __MODULE__, as: ETS

  use GenServer

  @behaviour OMana.Storage

  @table :o_mana_kv
  @expiry :o_mana_expiry

  def start_link(opts), do: GenServer.start_link(ETS, opts, name: opts[:name] || ETS)

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :named_table, :public, read_concurrency: true, write_concurrency: true])
    :ets.new(@expiry, [:set, :named_table, :public, write_concurrency: true])
    {:ok, %{}}
  end

  @impl OMana.Storage
  def get(key) when is_binary(key) do
    if expired?(key), do: :not_found, else: do_get(key)
  end

  defp do_get(key) do
    case :ets.lookup(@table, key) do
      [{^key, val}] -> {:ok, val}
      [] -> :not_found
    end
  end

  @impl OMana.Storage
  def exists?(key) do
    case get(key) do
      :not_found -> {:ok, false}
      {:ok, _} -> {:ok, true}
    end
  end

  @impl OMana.Storage
  def put(key, val) when is_binary(key) and is_binary(val) do
    :ets.insert(@table, {key, val})
    :ok
  end


  @impl OMana.Storage
  def del_many(keys) do
    Enum.reduce(keys, 0, fn k, acc ->
      acc + (if :ets.delete(@table, k) == true, do: 1, else: 0)
    end)
  end


  @impl OMana.Storage
  def expire(key, seconds) when is_integer(seconds) and seconds >= 0 do
    case do_get(key) do
      :not_found -> :not_found
      {:ok, _} ->
        now = System.monotonic_time(:millisecond)
        ttl_ms = :erlang.convert_time_unit(seconds, :second, :millisecond)
        :ets.insert(@expiry, {key, now + ttl_ms})
        :ok
    end
  end


  @impl OMana.Storage
  def ttl(key) do
    case do_get(key) do
      :not_found -> :not_found
      {:ok, _} ->
        case :ets.lookup(@expiry, key) do
          [{^key, deadline}] ->
            now = System.monotonic_time(:millisecond)
            if deadline <= now do
              :ets.delete(@table, key)
              :ets.delete(@expiry, key)
              :not_found
            else
              ms = deadline - now
              {:ok, div(ms + 999, 1000)} # ceil to seconds
            end
          [] -> :no_expiry
        end
    end
  end

  def sweep_expired do
    now = System.monotonic_time(:millisecond)
    for {key, deadline} <- :ets.tab2list(@expiry), deadline <= now do
      :ets.delete(@expiry, key)
      :ets.delete(@table, key)
    end
    :ok
  end

  defp expired?(key) do
    case :ets.lookup(@expiry, key) do
      [{^key, deadline}] ->
        if deadline <= System.monotonic_time(:millisecond) do
          :ets.delete(@expiry, key)
          :ets.delete(@table, key)
          true
        else
          false
        end
      [] -> false
    end
  end
end
