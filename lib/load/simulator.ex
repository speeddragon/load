defmodule Load.Simulator do
  @moduledoc """
  This module defines the contract for every implementation. Basically, all of
  them, should only prepare the payload which will be sent over the
  connection
  """

  @doc """
  This function processes the payload it receives, and returns the payload
  that will be send over the connection
  """
  @callback process(any()) :: any()

  @doc """
  This function is called when the response of the payload send is received.

  Note: it there a type for function ?
  """
  @callback handle_result(any(), any(), any(), any()) :: any()
end
