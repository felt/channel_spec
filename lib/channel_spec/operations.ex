defmodule ChannelSpec.Operations do
  @moduledoc """
  This module provides a way to define operations and subscriptions for a channel.
  """
  defmodule OperationError do
    defexception [:message, :module, :file, :line]

    def blame(exception, stack) do
      new_line =
        {exception.module, :operation, 2,
         [file: to_charlist(Path.relative_to_cwd(exception.file)), line: exception.line]}

      stack = [new_line | stack]

      {exception, stack}
    end
  end

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: [operation: 2, subscription: 2]
      Module.register_attribute(__MODULE__, :operations, accumulate: true)
      Module.register_attribute(__MODULE__, :subscriptions, accumulate: true)

      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)
    end
  end

  @doc """
  Defines an operation for the channel.

  Operations are functions that are called from the client to the server. They
  are defined with a name and a schema that describes the payload and the
  replies.

  Operation names can be atoms or strings. If the name is an atom, the function
  must be defined in the module. If the name is a string, the function does not
  need to be defined, as it implies it's dynamically matched by a `handle_in/3`
  callback.

  ## Examples

      defmodule MyChannel do
        use ChannelSpec.Operations

        operation :foo,
          payload: %{type: :string},
          replies: %{ok: %{type: :object}}
        
        def foo(_params, _context, socket), do: {:noreply, socket}
      end

  In the example above, we define an operation called `foo` that takes a
  string as a payload and replies with an object. The operation is implemented
  in the `foo/3` function. The `params` argument is the payload sent by the
  client, the `context` argument is the channel context, and the `socket`
  argument is the channel socket.
  """
  defmacro operation(name, params) when is_list(params) do
    file = __CALLER__.file
    line = __CALLER__.line
    module = __CALLER__.module

    has_payload? = Keyword.has_key?(params, :payload)
    has_replies? = Keyword.has_key?(params, :replies)

    params = Macro.prewalk(params, &expand_alias(&1, __CALLER__))

    if not has_payload? and not has_replies? do
      raise ArgumentError, "An operation must have at least a payload or replies schema"
    end

    line_metadata =
      Enum.reduce(params, %{}, fn
        {:replies, {:%{}, meta, children}}, lines ->
          children_lines =
            Map.new(children, fn
              {key, {_, child_meta, _}} -> {key, child_meta[:line]}
              {key, _} -> {key, meta[:line]}
            end)

          Map.put(lines, :replies, %{line: meta[:line], children: children_lines})

        {:payload, {_, meta, _}}, lines ->
          Map.put(lines, :payload, meta[:line])

        _other, lines ->
          lines
      end)
      |> Macro.escape()

    quote location: :keep,
          bind_quoted: [
            name: name,
            schema: params,
            file: file,
            line: line,
            module: module,
            line_metadata: line_metadata
          ] do
      operation = %{
        schema: schema,
        file: file,
        line: line,
        module: module,
        line_metadata: line_metadata
      }

      @operations {name, operation}

      def __channel_spec_operation__(unquote(name)), do: unquote(Macro.escape(operation))
    end
  end

  defmacro operation(_name, _params) do
    raise ArgumentError, "An operation must have at least a payload or replies schema"
  end

  @doc """
  Defines a subscription for the channel.

  Subscriptions are messages that are sent from the server to the client, without
  the client requesting them. They are defined with a name and a schema that
  describes the payload.

  ## Examples

      defmodule MyChannel do
        use ChannelSpec.Operations

        subscription "foo", payload: %{type: :string}
      end

  In the example above, we define a subscription for the event `foo` that takes
  a string as a payload.

  There is no function associated with a subscription, and they can be triggered
  from the server at any time, by any function.
  """
  defmacro subscription(event, schema) do
    file = __CALLER__.file
    line = __CALLER__.line
    module = __CALLER__.module
    line_metadata = Macro.escape(%{"event" => %{line: line}})
    schema = Macro.prewalk(schema, &expand_alias(&1, __CALLER__))

    quote location: :keep,
          bind_quoted: [
            event: event,
            file: file,
            line: line,
            module: module,
            schema: schema,
            line_metadata: line_metadata
          ] do
      subscription = %{
        schema: schema,
        file: file,
        line: line,
        module: module,
        line_metadata: line_metadata
      }

      @subscriptions {event, subscription}

      def __channel_spec_subscription__(unquote(event)), do: unquote(Macro.escape(subscription))
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:__attr__, 3}})

  defp expand_alias(other, _env), do: other

  defmacro __before_compile__(_env) do
    quote location: :keep do
      operations_map =
        for {operation, def} <- @operations, into: %{} do
          {operation, %{def | schema: unquote(__MODULE__).validate_operation(def)}}
        end

      subscriptions_map =
        for {subscription, definition} <- @subscriptions, into: %{} do
          {subscription, unquote(__MODULE__).validate_subscription(subscription, definition)}
        end

      @operations_map operations_map
      @subscriptions_map subscriptions_map

      def __channel_operations__() do
        @operations_map
      end

      def __channel_subscriptions__() do
        @subscriptions_map
      end
    end
  end

  def __after_compile__(env, _bytecode) do
    operations = env.module.__channel_operations__()

    for {operation, def} <- operations, is_atom(operation) do
      if not function_exported?(env.module, operation, 3) do
        raise OperationError,
          message: """
          The function #{operation}/3 is not defined in the handler #{inspect(env.module)}.
          """,
          module: def.module,
          file: def.file,
          line: def.line
      end
    end
  end

  @doc false
  def validate_operation(definition) do
    schema = Map.new(definition.schema)

    for {key, value} <- schema, into: %{} do
      case key do
        :payload ->
          {key, validate_schema!([:payload], definition, value)}

        :replies ->
          replies =
            for {reply, schema} <- value, into: %{} do
              {reply, validate_schema!([:replies, reply], definition, schema)}
            end

          {key, replies}

        _ ->
          {key, value}
      end
    end
  end

  @doc false
  def validate_subscription(event, definition) do
    validate_schema!(["subscription #{inspect(event)}"], definition, definition.schema)
  end

  defp validate_schema!(path, definition, schema) do
    if is_map(schema) or is_atom(schema) do
      schema
    else
      path_string = Enum.join(path, ".")

      raise %OperationError{
        message: """
        The schema for #{path_string} is not a valid schema map or module.
        """,
        module: definition.module,
        file: definition.file,
        line: get_line(definition.line_metadata, path)
      }
    end
  end

  defp get_line(_line_metadata, []) do
    raise "Missing line metadata"
  end

  defp get_line(line_metadata, [current]) do
    line_metadata[current]
  end

  defp get_line(line_metadata, [current | rest]) do
    get_line(line_metadata[current].children, rest)
  end
end
