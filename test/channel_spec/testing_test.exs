defmodule ChannelSpec.TestingTest do
  use ExUnit.Case, async: true
  use ChannelSpec.Testing

  def make_mod() do
    String.to_atom("Elixir.Test#{System.unique_integer([:positive])}")
  end

  def build_socket(module, id, assigns, endpoint, opts \\ []) do
    Phoenix.ChannelTest.__socket__(module, id, assigns, endpoint, opts)
  end

  setup do
    mod = make_mod()

    {:ok, mod: mod}
  end

  describe "push/3 and assert_reply_spec/3" do
    @tag :capture_log
    test "pushes message to channel", %{mod: mod} do
      defmodule :"#{mod}.RoomChannel" do
        use Phoenix.Channel
        use ChannelHandler.Router
        use ChannelSpec.Operations

        def join("room:" <> _, _params, socket) do
          {:ok, socket}
        end

        operation "new_msg",
          payload: %{type: :object, properties: %{body: %{type: :string}}},
          replies: %{ok: %{type: :string}}

        handle "new_msg", fn %{"body" => body}, _, socket ->
          {:reply, {:ok, body}, socket}
        end
      end

      defmodule :"#{mod}.UserSocket" do
        use ChannelSpec.Socket

        channel "room:*", :"#{mod}.RoomChannel"
      end

      defmodule :"#{mod}.Endpoint" do
        use Phoenix.Endpoint, otp_app: :channel_spec

        Phoenix.Endpoint.socket("/socket", :"#{mod}.UserSocket")

        defoverridable config: 1, config: 2
        def config(:pubsub_server), do: __MODULE__.PubSub
        def config(which), do: super(which)
        def config(which, default), do: super(which, default)
      end

      start_supervised({Phoenix.PubSub, name: :"#{mod}.Endpoint.PubSub"})

      {:ok, _endpoint_pid} = start_supervised(:"#{mod}.Endpoint")

      {:ok, _, socket} =
        :"#{mod}.UserSocket"
        |> build_socket("room:123", %{}, :"#{mod}.Endpoint")
        |> subscribe_and_join(:"#{mod}.RoomChannel", "room:123")

      ref = push(socket, "new_msg", %{"body" => "hello"})

      assert_reply_spec ref, :ok, reply
      assert reply == "hello"
    end

    @tag :capture_log
    test "validates response against the schema", %{mod: mod} do
      defmodule :"#{mod}.RoomChannel" do
        use Phoenix.Channel
        use ChannelHandler.Router
        use ChannelSpec.Operations

        def join("room:" <> _, _params, socket) do
          {:ok, socket}
        end

        operation "new_msg",
          payload: %{type: :object, properties: %{body: %{type: :string}}},
          replies: %{ok: %{type: :string}}

        handle "new_msg", fn %{"body" => body}, _, socket ->
          {:reply, {:ok, body}, socket}
        end
      end

      defmodule :"#{mod}.UserSocket" do
        use ChannelSpec.Socket

        channel "room:*", :"#{mod}.RoomChannel"
      end

      defmodule :"#{mod}.Endpoint" do
        use Phoenix.Endpoint, otp_app: :channel_spec

        Phoenix.Endpoint.socket("/socket", :"#{mod}.UserSocket")

        defoverridable config: 1, config: 2
        def config(:pubsub_server), do: __MODULE__.PubSub
        def config(which), do: super(which)
        def config(which, default), do: super(which, default)
      end

      start_supervised({Phoenix.PubSub, name: :"#{mod}.Endpoint.PubSub"})

      {:ok, _endpoint_pid} = start_supervised(:"#{mod}.Endpoint")

      {:ok, _, socket} =
        :"#{mod}.UserSocket"
        |> build_socket("room:123", %{}, :"#{mod}.Endpoint")
        |> subscribe_and_join(:"#{mod}.RoomChannel", "room:123")

      ref = push(socket, "new_msg", %{"body" => 123})

      error = catch_error(assert_reply_spec ref, :ok, _)

      assert error.message =~ "Channel reply doesn't match reply spec for status ok"
    end

    @tag :capture_log
    test "validates response against the schema in a handler module", %{mod: mod} do
      defmodule :"#{mod}.RoomChannel.Handler" do
        use ChannelHandler.Handler
        use ChannelSpec.Operations

        operation :msg,
          payload: %{type: :object, properties: %{body: %{type: :string}}},
          replies: %{ok: %{type: :string}}

        def msg(%{"body" => body}, _, socket) do
          {:reply, {:ok, body}, socket}
        end
      end

      defmodule :"#{mod}.RoomChannel" do
        use Phoenix.Channel
        use ChannelHandler.Router

        def join("room:" <> _, _params, socket) do
          {:ok, socket}
        end

        event "new_msg", :"#{mod}.RoomChannel.Handler", :msg
      end

      defmodule :"#{mod}.UserSocket" do
        use ChannelSpec.Socket

        channel "room:*", :"#{mod}.RoomChannel"
      end

      defmodule :"#{mod}.Endpoint" do
        use Phoenix.Endpoint, otp_app: :channel_spec

        Phoenix.Endpoint.socket("/socket", :"#{mod}.UserSocket")

        defoverridable config: 1, config: 2
        def config(:pubsub_server), do: __MODULE__.PubSub
        def config(which), do: super(which)
        def config(which, default), do: super(which, default)
      end

      start_supervised({Phoenix.PubSub, name: :"#{mod}.Endpoint.PubSub"})

      {:ok, _endpoint_pid} = start_supervised(:"#{mod}.Endpoint")

      {:ok, _, socket} =
        :"#{mod}.UserSocket"
        |> build_socket("room:123", %{}, :"#{mod}.Endpoint")
        |> subscribe_and_join(:"#{mod}.RoomChannel", "room:123")

      ref = push(socket, "new_msg", %{"body" => 123})

      assert_raise ChannelSpec.Testing.SpecError, fn ->
        assert_reply_spec ref, :ok
      end
    end

    @tag :capture_log
    test "__socket_schemas__ is optional", %{mod: mod} do
      defmodule :"#{mod}.RoomChannel" do
        use Phoenix.Channel

        def join("room:" <> _, _params, socket) do
          {:ok, socket}
        end

        def handle_in(_, _, socket) do
          {:reply, {:ok, :works}, socket}
        end
      end

      defmodule :"#{mod}.UserSocket" do
        use ChannelSpec.Socket

        channel "room:*", :"#{mod}.RoomChannel"
      end

      defmodule :"#{mod}.Endpoint" do
        use Phoenix.Endpoint, otp_app: :channel_spec

        Phoenix.Endpoint.socket("/socket", :"#{mod}.UserSocket")

        defoverridable config: 1, config: 2
        def config(:pubsub_server), do: __MODULE__.PubSub
        def config(which), do: super(which)
        def config(which, default), do: super(which, default)
      end

      start_supervised({Phoenix.PubSub, name: :"#{mod}.Endpoint.PubSub"})

      {:ok, _endpoint_pid} = start_supervised(:"#{mod}.Endpoint")

      {:ok, _, socket} =
        :"#{mod}.UserSocket"
        |> build_socket("room:123", %{}, :"#{mod}.Endpoint")
        |> subscribe_and_join(:"#{mod}.RoomChannel", "room:123")

      ref = push(socket, "new_msg", %{"body" => 123})

      assert_reply_spec ref, :ok, :works
    end

    @tag :capture_log
    test "channel spec is optional for the socket module", %{mod: mod} do
      defmodule :"#{mod}.RoomChannel" do
        use Phoenix.Channel

        def join("room:" <> _, _params, socket) do
          {:ok, socket}
        end

        def handle_in(_, _, socket) do
          {:reply, {:ok, :works}, socket}
        end
      end

      defmodule :"#{mod}.UserSocket" do
        use Phoenix.Socket

        channel "room:*", :"#{mod}.RoomChannel"
      end

      defmodule :"#{mod}.Endpoint" do
        use Phoenix.Endpoint, otp_app: :channel_spec

        Phoenix.Endpoint.socket("/socket", :"#{mod}.UserSocket")

        defoverridable config: 1, config: 2
        def config(:pubsub_server), do: __MODULE__.PubSub
        def config(which), do: super(which)
        def config(which, default), do: super(which, default)
      end

      start_supervised({Phoenix.PubSub, name: :"#{mod}.Endpoint.PubSub"})

      {:ok, _endpoint_pid} = start_supervised(:"#{mod}.Endpoint")

      {:ok, _, socket} =
        :"#{mod}.UserSocket"
        |> build_socket("room:123", %{}, :"#{mod}.Endpoint")
        |> subscribe_and_join(:"#{mod}.RoomChannel", "room:123")

      ref = push(socket, "new_msg", %{"body" => 123})

      assert_reply_spec ref, :ok, :works
    end
  end
end
