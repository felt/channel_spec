defmodule ChannelSpec.Testing do
  defmodule SpecError do
    defexception [:message]
  end

  defmacro __using__(_) do
    quote do
      import Phoenix.ChannelTest, except: [push: 3, subscribe_and_join: 3]

      import unquote(__MODULE__),
        only: [push: 3, assert_reply_spec: 2, assert_reply_spec: 3, subscribe_and_join: 3]
    end
  end

  @doc """
  See `Phoenix.ChannelTest.push/3`
  """
  def push(socket, event, payload) do
    ref = Phoenix.ChannelTest.push(socket, event, payload)
    socket = Phoenix.Socket.assign(socket, :__event__, event)
    Process.put(ref, socket)
    ref
  end

  @doc "See `subscribe_and_join!/4`."
  def subscribe_and_join!(socket, topic) when is_binary(topic) do
    subscribe_and_join!(socket, nil, topic, %{})
  end

  @doc "See `subscribe_and_join!/4`."
  def subscribe_and_join!(socket, topic, payload)
      when is_binary(topic) and is_map(payload) do
    subscribe_and_join!(socket, nil, topic, payload)
  end

  @doc """
  Same as `subscribe_and_join/4`, but returns either the socket
  or throws an error.

  This is helpful when you are not testing joining the channel
  and just need the socket.
  """
  def subscribe_and_join!(socket, channel, topic, payload \\ %{})
      when is_atom(channel) and is_binary(topic) and is_map(payload) do
    socket = assign_socket_metadata(socket, topic)
    Phoenix.ChannelTest.subscribe_and_join!(socket, channel, topic, payload)
  end

  @doc "See `subscribe_and_join/4`."
  def subscribe_and_join(socket, topic) when is_binary(topic) do
    subscribe_and_join(socket, nil, topic, %{})
  end

  @doc "See `subscribe_and_join/4`."
  def subscribe_and_join(socket, topic, payload)
      when is_binary(topic) and is_map(payload) do
    subscribe_and_join(socket, nil, topic, payload)
  end

  def subscribe_and_join(socket, channel_mod, topic, payload \\ %{}) do
    socket = assign_socket_metadata(socket, topic)
    Phoenix.ChannelTest.subscribe_and_join(socket, channel_mod, topic, payload)
  end

  @doc "See `join/4`"
  def join(socket, topic) when is_binary(topic) do
    join(socket, nil, topic, %{})
  end

  @doc "See `join/4`."
  def join(socket, topic, payload) when is_binary(topic) and is_map(payload) do
    join(socket, nil, topic, payload)
  end

  @doc """
  See `Phoenix.ChannelTest.join/4`.
  """
  def join(socket, channel, topic, payload \\ %{}) do
    socket = assign_socket_metadata(socket, topic)
    Phoenix.ChannelTest.join(socket, channel, topic, payload)
  end

  defp assign_socket_metadata(socket, topic) do
    case socket.handler.__channel__(topic) do
      {_mod, opts} ->
        assigns = opts[:assigns] || %{}
        Phoenix.Socket.assign(socket, assigns)

      _ ->
        socket
    end
  end

  @doc """
  Same as `Phoenix.ChannelTest.assert_reply/3` but verifies the reply
  against the schema defined for the socket that handled the message.
  """
  defmacro assert_reply_spec(
             ref,
             status,
             reply \\ quote do
               _
             end
           ) do
    quote location: :keep do
      socket = Process.get(unquote(ref))
      assert_reply(unquote(ref), unquote(status), reply = unquote(reply))

      normalized_reply = reply |> Jason.encode!() |> Jason.decode!()

      with true <- function_exported?(socket.handler, :__socket_schemas__, 0),
           socket_schema = socket.handler.__socket_schemas__(),
           topic = socket.assigns.__channel_topic__,
           event = socket.assigns.__event__,
           status = to_string(unquote(status)),
           %{} = schema <-
             socket_schema["channels"][topic]["messages"][event]["replies"][status] do
        case Xema.validate(schema, normalized_reply) do
          :ok ->
            :ok

          {:error, %m{} = error} ->
            raise SpecError,
              message: """
              Channel reply doesn't match reply spec for status #{status}:

              Reply:
                #{inspect(reply)}

              Error:
                #{m.format_error(error)}

              Schema:
                #{inspect(schema)}
              """
        end

        reply
      else
        _ -> reply
      end
    end
  end
end
