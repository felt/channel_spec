defmodule ChannelSpec.Cache.NoneCacheTest do
  use ExUnit.Case, async: true

  alias ChannelSpec.Cache.NoneCache

  describe "get/1" do
    test "returns nil" do
      assert is_nil(NoneCache.get(SomeModule))
    end
  end

  describe "put/2" do
    test "returns :ok" do
      assert :ok = NoneCache.put(SomeModule, %{})
    end
  end

  describe "erase/1" do
    test "returns :ok" do
      assert :ok = NoneCache.erase(SomeModule)
    end
  end
end
