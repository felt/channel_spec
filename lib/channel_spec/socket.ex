defmodule ChannelSpec.Socket do
  @moduledoc """
  This module provides a way to define a socket.
  """

  require Logger

  alias ChannelSpec.Schema

  defmacro __using__(opts) do
    {schema_path, opts} = Keyword.pop(opts, :schema_path)

    quote do
      use Phoenix.Socket, unquote(opts)
      import Phoenix.Socket, except: [channel: 2, channel: 3]
      import unquote(__MODULE__), only: [channel: 2, channel: 3]
      require Phoenix.Socket

      Module.register_attribute(__MODULE__, :__channels, accumulate: true)

      @__schema_path unquote(schema_path)

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Defines a channel for the socket.
  """
  defmacro channel(topic_pattern, module, opts \\ []) do
    pattern = String.replace_suffix(topic_pattern, "*", "{string}")
    topic_pattern = String.replace(topic_pattern, ~r/\{.*\}.*/, "*")

    quote location: :keep do
      opts =
        Keyword.update(
          unquote(opts),
          :assigns,
          %{__channel_topic__: unquote(pattern)},
          fn assigns ->
            assigns
            |> Keyword.put(:__channel_topic__, unquote(pattern))
          end
        )

      @__channels {unquote(pattern), unquote(module), unquote(opts)}
      Phoenix.Socket.channel(unquote(topic_pattern), unquote(module), opts)
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      def __registered_channels__ do
        @__channels
      end

      if is_binary(@__schema_path) do
        socket_tree = unquote(__MODULE__).build_ops_tree(@__channels)
        unquote(__MODULE__).write_schema(socket_tree, @__schema_path)
      end

      def __socket_tree__() do
        case ChannelSpec.Cache.adapter().get({__MODULE__, :socket_tree}) do
          nil ->
            tree = unquote(__MODULE__).build_ops_tree(@__channels)
            ChannelSpec.Cache.adapter().put({__MODULE__, :socket_tree}, tree)
            tree

          tree ->
            tree
        end
      end

      def __socket_schemas__() do
        case ChannelSpec.Cache.adapter().get({__MODULE__, :socket_schemas}) do
          nil ->
            tree = unquote(__MODULE__).build_schemas(__socket_tree__())
            ChannelSpec.Cache.adapter().put({__MODULE__, :socket_schemas}, tree)
            tree

          tree ->
            tree
        end
      end
    end
  end

  @doc false
  def write_schema(socket_tree, path) do
    schema_string = Serializer.to_string(socket_tree)
    File.write!(path, schema_string)
  end

  @doc false
  def build_ops_tree(channels) do
    channels =
      for {topic, module, _opts} <- channels,
          Code.ensure_compiled(module),
          function_exported?(module, :spark_dsl_config, 0),
          into: %{} do
        router = module.spark_dsl_config()[[:router]]
        entities = if router, do: router.entities, else: []

        ops_tree =
          for entity <- entities,
              operation <- get_operations(entity, module),
              reduce: %{} do
            messages ->
              if Map.has_key?(messages, operation.event) do
                Logger.warning("""
                A previous clause for the event "#{operation.event}" has been defined in the module #{inspect(module)}.
                This clause will be ignored.
                #{IO.ANSI.white()}#{module.module_info()[:compile][:source] |> Path.relative_to_cwd()} #{inspect(module)}#{IO.ANSI.reset()}
                """)

                messages
              else
                Map.put(messages, operation.event, operation)
              end
          end

        subscriptions =
          if function_exported?(module, :__channel_subscriptions__, 0) do
            module.__channel_subscriptions__()
          else
            %{}
          end

        {topic, %{messages: ops_tree, subscriptions: subscriptions}}
      end

    {channels, refs} = Schema.compile_refs(channels)

    definitions =
      for {module, schema} <- refs, into: %{} do
        {Schema.ref_name(module, schema), schema}
      end

    %{
      channels: channels,
      definitions: definitions
    }
  end

  @doc false
  def build_schemas(socket_tree) do
    socket_tree = socket_tree |> Jason.encode!() |> Jason.decode!()

    definitions = socket_tree[:definitions] || socket_tree["definitions"]

    main_xema = Xema.from_json_schema(%{"definitions" => definitions})
    refs = main_xema.refs

    defs =
      Map.new(main_xema.schema.definitions, fn {key, value} -> {"#/definitions/#{key}", value} end)

    main = Map.merge(defs, refs)

    socket_tree
    |> Map.delete("definitions")
    |> build_schemas(main)
  end

  @doc false
  def build_schemas(map, main) when is_map(map) do
    Map.new(map, fn
      {"channels", channels} ->
        channels =
          for {topic, topic_def} <- channels, into: %{} do
            messages = topic_def["messages"]

            messages =
              for {event, operation} <- messages, into: %{} do
                schema = operation["schema"]

                payload =
                  %{JsonXema.new(schema["payload"], remotes: false) | refs: main}
                  |> JsonXema.to_xema()

                replies =
                  for {status, reply} <- schema["replies"] || [], into: %{} do
                    reply =
                      %{JsonXema.new(reply, remotes: false) | refs: main} |> JsonXema.to_xema()

                    {status, reply}
                  end

                {event, %{"payload" => payload, "replies" => replies}}
              end

            subscriptions =
              for {event, subscription} <- topic_def["subscriptions"] || %{}, into: %{} do
                subscription =
                  %{JsonXema.new(subscription, remotes: false) | refs: main} |> JsonXema.to_xema()

                {event, subscription}
              end

            {topic, %{"messages" => messages, "subscriptions" => subscriptions}}
          end

        {"channels", channels}

      {key, value} ->
        {key, value}
    end)
  end

  @doc false
  def resolve_refs(schema, master) do
    do_resolve_refs(schema.schema, master)
  end

  defp do_resolve_refs(%{ref: %Xema.Ref{} = ref}, master) do
    Xema.Schema.fetch!(master, ref.pointer)
  end

  defp do_resolve_refs(%Xema.Schema{} = schema, master) do
    struct(
      Xema.Schema,
      schema
      |> Map.from_struct()
      |> Enum.map(fn {key, value} ->
        {key, do_resolve_refs(value, master)}
      end)
    )
  end

  defp do_resolve_refs(list, master) when is_list(list) do
    Enum.map(list, &do_resolve_refs(&1, master))
  end

  defp do_resolve_refs(value, _master), do: value

  defp get_operations(entity, router, prefix \\ "")

  defp get_operations(
         %ChannelHandler.Dsl.Scope{prefix: prefix, handlers: handlers},
         router,
         _prefix
       ) do
    for handler <- handlers, operation <- get_operations(handler, router, prefix) do
      %{
        event: prefix <> operation.event,
        schema: operation.schema,
        module: operation.module,
        function: operation.function,
        file: operation.file,
        line: operation.line
      }
    end
  end

  defp get_operations(%ChannelHandler.Dsl.Event{} = event, _router, _prefix) do
    Code.ensure_compiled(event.module)

    if function_exported?(event.module, :__channel_operations__, 0) do
      operations = event.module.__channel_operations__()

      case Enum.find(operations, fn {function, _} -> function == event.function end) do
        nil ->
          []

        {_, operation} ->
          [
            %{
              event: event.name,
              schema: operation.schema,
              module: event.module,
              function: event.function,
              file: operation.file,
              line: operation.line
            }
          ]
      end
    else
      []
    end
  end

  defp get_operations(%ChannelHandler.Dsl.Delegate{} = delegate, _router, _prefix) do
    Code.ensure_compiled(delegate.module)

    if function_exported?(delegate.module, :__channel_operations__, 0) do
      operations = delegate.module.__channel_operations__()

      for {event, operation} <- operations, is_binary(event) do
        %{
          event: delegate.prefix <> event,
          schema: operation.schema,
          module: delegate.module,
          function: :handle_in,
          file: operation.file,
          line: operation.line
        }
      end
    else
      []
    end
  end

  defp get_operations(%ChannelHandler.Dsl.Handle{} = handle, router, prefix) do
    if function_exported?(router, :__channel_operations__, 0) do
      operations = router.__channel_operations__()

      case Enum.find(operations, fn {operation, _} -> operation == prefix <> handle.name end) do
        nil ->
          []

        {_, operation} ->
          [
            %{
              event: handle.name,
              schema: operation.schema,
              module: router,
              function: :handle_in,
              file: operation.file,
              line: operation.line
            }
          ]
      end
    else
      []
    end
  end

  defp get_operations(_entity, _router, _prefix), do: []
end
