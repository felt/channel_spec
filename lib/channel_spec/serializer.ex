defmodule Serializer do
  @moduledoc false

  @spec to_schema(map()) :: map()
  def to_schema(socket_tree) do
    Map.new(socket_tree, fn
      {:messages, messages} ->
        messages = Map.new(messages, fn {event, operation} -> {event, operation.schema} end)
        {:messages, messages}

      {key, %Xema.Schema{} = schema} ->
        {key, Xema.Schema.to_map(schema)}

      {key, %JsonXema{} = schema} ->
        xema = JsonXema.to_xema(schema)
        schema = Xema.Schema.to_map(xema.schema)
        {key, schema}

      {key, map} when is_map(map) ->
        {key, to_schema(map)}

      {key, list} when is_list(list) ->
        {key, Enum.map(list, &to_schema/1)}

      {key, value} ->
        {key, value}
    end)
  end

  @spec to_string(map()) :: String.t()
  def to_string(socket_tree) do
    socket_tree
    |> to_schema()
    |> Jason.encode!(pretty: true)
  end
end
