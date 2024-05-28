defmodule Serializer do
  @moduledoc false

  @spec to_schema(map()) :: map()
  def to_schema(socket_tree) do
    Map.new(socket_tree, fn
      {:messages, messages} ->
        messages = Map.new(messages, fn {event, operation} -> {event, operation.schema} end)
        {:messages, messages}

      {:required, required} when is_list(required) ->
        {:required, required}

      {:enum, enum} when is_list(enum) ->
        {:enum, enum}

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
    |> to_ordered_structs()
    |> Jason.encode!(pretty: true)
  end

  # Helper function to ensure the order of the output json
  @spec to_ordered_structs(map()) :: Jason.OrderedObject.t()
  defp to_ordered_structs(map) when is_map(map) do
    map
    |> Enum.to_list()
    |> Enum.sort_by(fn {key, _val} -> key end, :desc)
    |> Enum.reduce(%Jason.OrderedObject{}, fn
      {key, value}, acc when is_map(value) ->
        %{acc | values: [{key, to_ordered_structs(value)} | acc.values]}

      {key, value}, acc when is_list(value) ->
        %{acc | values: [{key, to_ordered_structs(value)} | acc.values]}

      {key, value}, acc ->
        %{acc | values: [{key, value} | acc.values]}
    end)
  end

  defp to_ordered_structs(list) when is_list(list), do: Enum.map(list, &to_ordered_structs/1)
  defp to_ordered_structs(other), do: other
end
