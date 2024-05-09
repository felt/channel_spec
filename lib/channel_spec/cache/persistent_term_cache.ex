defmodule ChannelSpec.Cache.PersistentTermCache do
  @moduledoc """
  A cache adapter that stores the specs in memory.

  This is the default cache adapter.
  """

  @behaviour ChannelSpec.Cache

  @impl true
  def get(spec_module) do
    :persistent_term.get(spec_module, nil)
  end

  @impl true
  def put(spec_module, specs) do
    :persistent_term.put(spec_module, specs)
  end

  @impl true
  def erase(spec_module) do
    :persistent_term.erase(spec_module)
  end
end
