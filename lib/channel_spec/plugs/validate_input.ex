defmodule ChannelSpec.Plugs.ValidateInput do
  @behaviour ChannelHandler.Plug

  def call(socket, payload, context, _opts) do
    topic = socket.assigns.__channel_topic__
    schemas = socket.handler.__socket_schemas__()

    schema = schemas["channels"][topic]["messages"][context.full_event]["payload"]

    case Xema.validate(schema, payload) do
      :ok ->
        {:cont, socket, payload, context}

      {:error, %m{} = errors} ->
        {:reply, {:error, "Invalid input: #{m.format_error(errors)}"}, socket}
    end
  end
end
