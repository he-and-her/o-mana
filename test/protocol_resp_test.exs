defmodule OMana.Protocol.RESPTest do
  use ExUnit.Case, async: true
  alias OMana.Protocol.RESP

  test "parse and encode round-trip for a simple command" do
    req = "*2\r\n$4\r\nECHO\r\n$3\r\nhey\r\n"
    {[argv], rest} = RESP.parse_many(req)
    assert rest == ""
    assert argv == ["ECHO", "hey"]

    assert RESP.encode("hey") == "$3\r\nhey\r\n"
  end

  test "null bulk" do
    assert RESP.encode(nil) == "$-1\r\n"
  end
end
