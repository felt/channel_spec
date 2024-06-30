defmodule ChannelSpec.OperationsTest do
  use ExUnit.Case, async: true

  alias ChannelSpec.Operations

  def make_mod(), do: String.to_atom("Elixir.Test#{System.unique_integer([:positive])}")

  describe "operation/2" do
    setup do
      mod = make_mod()

      {:ok, mod: mod}
    end

    test "stores the operation", %{mod: mod} do
      defmodule :"#{mod}" do
        use ChannelSpec.Operations

        operation :foo,
          payload: %{type: :string},
          replies: %{ok: %{type: :object}}

        def foo(_params, _context, socket), do: {:noreply, socket}
      end

      assert operations = mod.__channel_operations__()

      assert %{
               module: ^mod,
               schema: %{payload: %{type: :string}}
             } = operations.foo
    end

    test "raises an error if the operation function is not defined", %{mod: mod} do
      assert %Operations.OperationError{} =
               err =
               catch_error(
                 defmodule :"#{mod}" do
                   use ChannelSpec.Operations

                   operation :foo, payload: %{type: :string}
                 end
               )

      assert err.message == "The function foo/3 is not defined in the handler #{inspect(mod)}.\n"
    end

    test "doesn't require the operation function to be defined if the name is a string", %{
      mod: mod
    } do
      defmodule :"#{mod}" do
        use ChannelSpec.Operations

        operation "foo", payload: %{type: :string}
      end

      assert operations = mod.__channel_operations__()

      assert %{
               module: ^mod,
               schema: %{payload: %{type: :string}}
             } = operations["foo"]
    end

    test "validates that the payload schema is valid", %{mod: mod} do
      assert %Operations.OperationError{} =
               err =
               catch_error(
                 defmodule :"#{mod}" do
                   use ChannelSpec.Operations

                   operation :foo, payload: 123
                   def foo(_params, _context, socket), do: {:noreply, socket}
                 end
               )

      assert err.message == "The schema for payload is not a valid schema map or module.\n"
    end

    test "validates that the replies schemas are valid", %{mod: mod} do
      assert %Operations.OperationError{} =
               err =
               catch_error(
                 defmodule :"#{mod}" do
                   use ChannelSpec.Operations

                   operation :foo, replies: %{ok: 123}
                   def foo(_params, _context, socket), do: {:noreply, socket}
                 end
               )

      assert err.message == "The schema for replies.ok is not a valid schema map or module.\n"
    end

    test "validates that at least the payload schema is defined" do
      assert %ArgumentError{} =
               err =
               catch_error(
                 defmodule :"#{make_mod()}" do
                   use ChannelSpec.Operations

                   operation :foo, []
                   def foo(_params, _context, socket), do: {:noreply, socket}
                 end
               )

      assert err.message == "An operation must have at least a payload or replies schema"

      defmodule :"#{make_mod()}" do
        use ChannelSpec.Operations

        operation :foo, payload: %{type: :string}
        def foo(_params, _context, socket), do: {:noreply, socket}
      end
    end

    test "validates that at least the replies schemas are defined" do
      assert %ArgumentError{} =
               err =
               catch_error(
                 defmodule :"#{make_mod()}" do
                   use ChannelSpec.Operations

                   operation :foo, []
                   def foo(_params, _context, socket), do: {:noreply, socket}
                 end
               )

      assert err.message == "An operation must have at least a payload or replies schema"

      defmodule :"#{make_mod()}" do
        use ChannelSpec.Operations

        operation :foo, replies: %{ok: %{type: :string}}
        def foo(_params, _context, socket), do: {:noreply, socket}
      end
    end

    test "validates that the schemas is a keyword list" do
      assert %ArgumentError{} =
               err =
               catch_error(
                 defmodule :"#{make_mod()}" do
                   use ChannelSpec.Operations

                   operation :foo, 123
                   def foo(_params, _context, socket), do: {:noreply, socket}
                 end
               )

      assert err.message == "An operation must have at least a payload or replies schema"

      defmodule :"#{make_mod()}" do
        use ChannelSpec.Operations

        operation :foo, payload: %{type: :string}, replies: %{ok: %{type: :string}}
        def foo(_params, _context, socket), do: {:noreply, socket}
      end
    end
  end

  describe "subscription/2" do
    setup do
      mod = make_mod()

      {:ok, mod: mod}
    end

    test "stores the subscription schema", %{mod: mod} do
      defmodule :"#{mod}" do
        use ChannelSpec.Operations

        subscription :foo, %{type: :string}

        def foo(_params, _context, socket), do: {:noreply, socket}
      end

      assert subscriptions = mod.__channel_subscriptions__()

      assert %{
               foo: %{type: :string}
             } = subscriptions
    end

    test "validates that the schema is valid", %{mod: mod} do
      assert %Operations.OperationError{} =
               err =
               catch_error(
                 defmodule :"#{mod}" do
                   use ChannelSpec.Operations

                   subscription "foo", 123
                   def foo(_params, _context, socket), do: {:noreply, socket}
                 end
               )

      assert err.message == ~s(The schema for subscription "foo" is not a valid schema map or module.\n)
    end
  end
end
