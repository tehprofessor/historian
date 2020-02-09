defmodule HistorianTest do
  use ExUnit.Case
  doctest Historian

  test "greets the world" do
    assert Historian.hello() == :world
  end
end
