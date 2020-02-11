defmodule Historian.Clipboard do
  @moduledoc """
  Functionality related to copy and pasting using the operating system's clipboard.
  """

  @type success() :: {:ok, :copied_to_clipboard}
  @type unknown_os_error() :: {:error, :unknown_os}
  @type missing_x_server() :: {:error, :missing_x_server}

  @type copy_result :: success | unknown_os_error | missing_x_server

  @spec copy(String.t()) :: copy_result()
  def copy(value) do
    detect_os() |> do_copy(value)
  end

  @spec paste() :: {:ok, String.t()} | {:error, :paste_failed}
  def paste() do
    os = detect_os()

    with {data, 0} <- do_paste(os) do
      {:ok, data}
    else
      _ -> {:error, :paste_failed}
    end
  end

  defp do_copy(:macos, value) when is_binary(value) do
    port = Port.open({:spawn, "pbcopy"}, [:binary])
    _ = send(port, {self(), {:command, value}})
    _ = send(port, {self(), :close})

    {:ok, :copied_to_clipboard}
  end

  defp do_copy(:linux, value) when is_binary(value) do
    if System.get_env("DISPLAY") do
      port = Port.open({:spawn, "xclip -sel clip"}, [:binary])
      _ = send(port, {self(), {:command, value}})
      _ = send(port, {self(), :close})

      {:ok, :copied_to_clipboard}
    else
      # If folks are logged into a via SSH this is likely to happen
      {:error, :missing_x_server}
    end
  end

  defp do_copy(:windows, value) when is_binary(value) do
    port = Port.open({:spawn, "clip"}, [:stream, :binary])
    _ = send(port, {self(), {:command, value}})
    _ = send(port, {self(), :close})

    {:ok, :copied_to_clipboard}
  end

  defp do_copy(:i_am_sorry_open_a_pr_with_your_os_copy_command_and_i_will_support_you, _value) do
    {:error, :unknown_os}
  end

  defp do_paste(:macos) do
    System.cmd("pbpaste", [])
  end

  defp do_paste(:windows) do
    System.cmd("paste", [])
  end

  defp do_paste(:linux) do
    System.cmd("xclip", ["-out -sel clip"])
  end

  defp detect_os do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:win32, :nt} -> :windows
      {:unix, :linux} -> :linux
      _ -> :i_am_sorry_open_a_pr_with_your_os_copy_command_and_i_will_support_you
    end
  end
end
