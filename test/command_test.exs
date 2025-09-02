defmodule OMana.CommandTest do
  use ExUnit.Case, async: false

  alias OMana.Command
  alias OMana.Storage.ETS, as: KV

  setup do
    start_supervised!({OMana.Storage.ETS, name: OMana.Storage.ETS})
    :ok
  end

  test "SET/GET" do
    assert Command.dispatch(KV, ["SET", "a", "1"]) == {:ok, "OK"}
    assert Command.dispatch(KV, ["GET", "a"]) == "1"
  end

  test "INCR" do
    assert Command.dispatch(KV, ["INCR", "n"]) == {:int, 1}
    assert Command.dispatch(KV, ["INCR", "n"]) == {:int, 2}
  end

  test "EXPIRE/TTL" do
    assert Command.dispatch(KV, ["SET", "k", "v"]) == {:ok, "OK"}
    assert Command.dispatch(KV, ["EXPIRE", "k", "1"]) == {:int, 1}

    case KV.ttl("k") do
      {:ok, s} -> assert s in 0..1
      other -> flunk("unexpected ttl: #{inspect(other)}")
    end
  end
end
