defmodule ChannelSpec.Schema do
  @moduledoc """
  This module provides a way to define schemas for a channel.
  """

  @type t :: map()

  @doc """
  Called when resolving a reference in a schema.
  """
  @callback schema() :: t()

  @doc false
  @spec compile_refs(t()) :: {t(), map()}
  def compile_refs(schema) do
    compile_refs(schema, %{}, follow_refs: true)
  end

  defp compile_refs(schema, refs, opts)

  defp compile_refs(%{schema: schema} = operation, refs, opts) do
    {schema, refs} =
      if schema[:replies] do
        {replies, refs} =
          for {reply, schema} <- schema[:replies], reduce: {%{}, refs} do
            {replies, refs} ->
              {schema, refs} = compile_refs(schema, refs, opts)
              {Map.put(replies, reply, schema), refs}
          end

        {Map.put(schema, :replies, replies), refs}
      else
        {schema, refs}
      end

    {schema, refs} =
      if schema[:payload] do
        {payload, refs} = compile_refs(schema[:payload], refs, opts)
        {Map.put(schema, :payload, payload), refs}
      else
        {schema, refs}
      end

    {%{operation | schema: schema}, refs}
  end

  defp compile_refs(module, refs, opts) when is_atom(module) do
    if function_exported?(module, :schema, 0) do
      schema = module.schema()
      compile_refs(schema, refs, opts)
    else
      {module, refs}
    end
  end

  defp compile_refs(%{"$ref": ref} = schema, refs, opts) do
    {ref_string, refs} =
      if Keyword.get(opts, :follow_refs, true) do
        resolve_ref(ref, refs)
      else
        ref_string = "#/definitions/#{ref_name(ref, %{})}"
        refs = Map.update(refs, :__unresolved_refs, [ref], &[ref | &1])
        {ref_string, refs}
      end

    schema = Map.put(schema, :"$ref", ref_string)

    {schema, refs}
  end

  defp compile_refs(schema, refs, opts) when is_map(schema) do
    {schema, refs} =
      Enum.reduce(schema, {%{}, refs}, fn
        {key, value}, {schema, refs} ->
          {value, refs} = compile_refs(value, refs, opts)

          {Map.put(schema, key, value), refs}
      end)

    {schema, refs}
  end

  defp compile_refs(list, refs, opts) when is_list(list) do
    {list, refs} =
      Enum.reduce(list, {[], refs}, fn
        value, {list, refs} ->
          {value, refs} = compile_refs(value, refs, opts)

          {[value | list], refs}
      end)

    {Enum.reverse(list), refs}
  end

  defp compile_refs(schema, refs, _opts) do
    {schema, refs}
  end

  defp resolve_ref(ref, refs) do
    if ref in Map.keys(refs) do
      ref_string = "#/definitions/#{ref_name(ref, %{})}"
      {ref_string, refs}
    else
      {schema, refs} = compile_refs(ref.schema(), refs, follow_refs: false)
      refs = Map.put(refs, ref, schema)
      ref_string = "#/definitions/#{ref_name(ref, schema)}"

      refs =
        if not Enum.empty?(refs[:__unresolved_refs] || []) do
          for ref <- refs.__unresolved_refs, reduce: refs do
            refs ->
              schema = ref.schema()
              refs = Map.put(refs, ref, schema)
              refs = Map.update(refs, :__unresolved_refs, [], &(&1 -- [ref]))

              {schema, refs} = compile_refs(schema, refs, [])

              Map.put(refs, ref, schema)
          end
          |> Map.delete(:__unresolved_refs)
        else
          refs
        end

      {ref_string, Map.put(refs, ref, schema)}
    end
  end

  @doc false
  def ref_name(module, ref) when is_map(ref) do
    ref[:title] ||
      module
      |> Module.split()
      |> List.last()
  end
end
