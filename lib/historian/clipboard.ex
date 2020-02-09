defmodule Historian.Clipboard do
  @moduledoc false

  def copy(:macos, value) when is_binary(value) do
    port = Port.open({:spawn, "pbcopy"}, [:binary])
    send(port, {self(), {:command, value}})
    send(port, {self(), :close})
  end
end
