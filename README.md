# ChannelSpec

A Phoenix Channels specification library for automatic data validation and schema generation inspired by OpenAPI and built on top of [ChannelHandler](https://hex.pm/packages/channel_handler).

## Installation

You can install ChannelSpec from git, and ChannelHandler from Hex:

```elixir
def deps do
  [
    {:channel_handler, "~> 0.6"},
    {:channel_spec, github: "felt/channel_spec"}
  ]
end
```

## Usage

First, you need to define the Phoenix Socket module by using `ChannelSpec.Socket`:

```elixir
defmodule MyAppWeb.UserSocket do
  use ChannelSpec.Socket

  channel "room:*", MyAppWeb.RoomChannel
end
```

Then, you must define the channel module. For this, you have to use three modules:

- `Phoenix.Channel` for basic Channel functionality
- `ChannelHandler.Router` to define the event routing
- `ChannelSpec.Operations` to define operation schemas

```elixir
defmodule MyAppWeb.RoomChannel do
  use Phoenix.Channel
  use ChannelHandler.Router
  use ChannelSpec.Operations

  join fn _topic, _payload, socket ->
    {:ok, socket}
  end

  operation "new_msg",
    payload: %{
      type: :object,
      properties: %{text: %{type: :string}}
    },
    replies: %{
      ok: %{type: :string},
      error: %{type: :string}
    }

  handle "new_msg", fn %{"text" => text}, _context, socket ->
    {:reply, {:ok, text}, socket}
  end
end
```

This will tell ChannelSpec that the server is capable of receiving a `"new_msg"` event,
with a map with a key `text` of type `string` and that it will reply with a `string` both
in case of success and error.

By using ChannelSpec, the following features will be available:

- A schema file can be automatically generated by passing the `:schema_path` option to `use ChannelSpec.Socket`
- Using `plug ChannelSpec.Plugs.ValidateInput` will allow you to validate incoming payloads against your operation schemas
- `mix channelspec.routes MyAppWeb.Endpoint` to list all available events and their handlers, as defined with `ChannelHandler.Router`. Passing the `--verbose` flag will also include file:line information about the files where the operation and the handler function are defined.
- Testing that reply values conform to spec with `ChannelSpec.Testing.assert_reply_spec`

### Validating user input

If you add `plug ChannelSpec.Plugs.ValidateInput` to your channel or handler modules, the incoming message
payloads will be validated against your schemas. In case of a validation error, an error will immediately
be returned to the client.

### Generating schema files

You can configure the socket module to generate a schema file, that can be used to generate bindings for
client code or documentation:

```elixir
defmodule MyAppWeb.UserSocket do
  use ChannelSpec.Socket, schema_path: "priv/schema.json"
end
```

### Testing

You can use ChannelSpec's enhanced test helpers to verify the channel replies conform to the specified schemas:

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use ExUnit.Case, async: true
  use ChannelSpec.Testing

  setup do
    {:ok, _, socket} =
      MyAppWeb.UserSocket
      |> socket("123", %{})
      |> subscribe_and_join(MyAppWeb.RoomChannel, "room:123")

    %{socket: socket}
  end

  test "returns a valid reply", %{socket: socket} do
    # Send a number body instead of a string
    ref = push(socket, "new_msg", %{body: 123}

    assert_reply_spec ref, :ok, reply # Will raise a validation error!
    assert is_binary(reply)
  end
end
```

## Creating client bindings

You can use the generate schema file to generate client bindings.
For Typescript bindings, you can use the companion [channel_spec_tscodegen](https://github.com/felt/channel_spec_tscodegen) tool.
