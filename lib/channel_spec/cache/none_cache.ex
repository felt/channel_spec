defmodule ChannelSpec.Cache.NoneCache do
  @moduledoc """
  A cache adapter to disable caching. Intended to be used in development.

  Configure it with:

  ```elixir
  # config/runtime.exs
  config :channel_handler, :cache_adapter, ChannelSpec.Cache.NoneCache
  ```
  """

  @behaviour ChannelSpec.Cache

  @impl true
  def get(_spec_module), do: nil

  @impl true
  def put(_spec_module, _spec), do: :ok

  @impl true
  def erase(_spec_module), do: :ok
end
