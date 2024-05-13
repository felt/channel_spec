defmodule ChannelSpec.Cache do
  @moduledoc """
  Cache for ChannelSpec specs.

  Settings:

  ```elixir
  config :channel_spec, :cache_adapter, Module
  ```

  ChannelSpec ships with two cache adapters:

  * `ChannelSpec.Cache.PersistentTermCache` - default
  * `ChannelSpec.Cache.NoneCache` - none cache

  If you are constantly modifying specs during development, you can configure the cache adapter
  in `dev.exs` as follows to disable caching:

  ```elixir
  config :channel_spec, :cache_adapter, ChannelSpec.Cache.NoneCache
  ```
  """

  @callback get(module) :: nil | map()
  @callback put(module, map()) :: :ok
  @callback erase(module) :: :ok

  @default_adapter ChannelSpec.Cache.PersistentTermCache

  @doc """
  Get cache adapter
  """
  @spec adapter() :: module()
  def adapter() do
    Application.get_env(:channel_spec, :cache_adapter, @default_adapter)
  end
end
