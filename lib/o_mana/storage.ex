defmodule OMana.Storage do
  @moduledoc """
  Behaviour for key-value storage plane + expiry hooks.
  """

  @callback get(key :: binary()) :: :not_found | {:ok, binary()}
  @callback exists?(key :: binary()) :: {:ok, boolean()}
  @callback put(key :: binary(), value :: binary()) :: :ok
  @callback del_many(keys :: [binary()]) :: non_neg_integer()
  @callback expire(key :: binary(), seconds :: non_neg_integer()) :: :ok | :not_found
  @callback ttl(key :: binary()) :: :not_found | :no_expiry | {:ok, non_neg_integer()}

  def get(mod, key), do: mod.get(key)
  def exists?(mod, key), do: mod.exists?(key)
  def put(mod, key, val), do: mod.put(key, val)
  def del_many(mod, keys), do: mod.del_many(keys)
  def expire(mod, key, sec), do: mod.expire(key, sec)
  def ttl(mod, key), do: mod.ttl(key)
end
