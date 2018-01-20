defmodule DDTest do
  use ExUnit.Case
  doctest DD

  test "greets the world" do
    assert DD.hello() == :world
  end
end
