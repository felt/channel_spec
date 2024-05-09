defmodule Mix.Tasks.ChannelSpec.Routes do
  @moduledoc """
  This task prints the routes for the channels in the application.
  """
  @shortdoc "Prints the routes for the channels in the application"

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("compile", argv)
    Mix.Task.reenable("channel_spec.routes")

    {opts, [module_string], _} = OptionParser.parse(argv, switches: [verbose: :boolean])
    endpoint_module = String.to_atom("Elixir." <> module_string)

    for {path, socket_module, _} <- endpoint_module.__sockets__() do
      try do
        ChannelSpec.Cache.adapter().erase({socket_module, :socket_tree})
        socket_tree = socket_module.__socket_tree__()
        IO.puts(IO.ANSI.faint() <> "#{path}" <> IO.ANSI.reset())
        print_socket_routes(socket_module, socket_tree, opts)
      rescue
        _e in UndefinedFunctionError ->
          :ok
      end
    end
  end

  defp print_socket_routes(socket_module, socket_tree, opts) do
    verbose = Keyword.get(opts, :verbose, false)

    channels =
      for {channel, schema} <- socket_tree.channels do
        {channel, schema.messages}
      end

    channels = Enum.sort_by(channels, fn {channel, _} -> channel end)

    for {channel, operations} <- channels do
      IO.puts("  " <> IO.ANSI.light_cyan() <> "#{channel}")

      if verbose do
        socket_file = get_file_path(socket_module) |> Path.relative_to_cwd()

        IO.puts(
          IO.ANSI.faint() <>
            "  └─" <> "#{socket_file} #{inspect(socket_module)}" <> IO.ANSI.reset()
        )
      end

      {event_len, module_len, function_len} = calculate_column_widths(operations)

      operations = Enum.sort_by(operations, fn {event, _} -> event end)

      operations_iolist =
        for {_, operation} <- operations do
          module = inspect(operation.module)
          function = inspect(operation.function)

          line =
            "    " <>
              IO.ANSI.green() <>
              String.pad_trailing(operation.event, event_len) <>
              "    " <>
              IO.ANSI.yellow() <>
              String.pad_trailing(module, module_len) <>
              "    " <>
              IO.ANSI.light_blue() <> String.pad_trailing(function, function_len) <> "\n"

          if verbose do
            op_file = Path.relative_to_cwd(operation.file)
            handler_file = Path.relative_to_cwd(get_file_path(operation.module))
            handler_line = get_line_number(operation.module, operation.function)

            line <>
              IO.ANSI.light_black() <>
              "    ├─ Schema: #{op_file}:#{operation.line}\n" <>
              "    └─ Handler: #{handler_file}:#{handler_line}\n"
          else
            line
          end
        end

      IO.puts([operations_iolist | IO.ANSI.reset()])
    end
  end

  defp calculate_column_widths(operations) do
    Enum.reduce(operations, {0, 0, 0}, fn {_, operation}, acc ->
      %{event: event, module: module, function: function} = operation
      module = inspect(module)
      function = inspect(function)

      {event_len, module_len, function_len} = acc

      {max(event_len, String.length(event)), max(module_len, String.length(module)),
       max(function_len, String.length(function))}
    end)
  end

  defp get_file_path(module_name) do
    [compile_infos] = Keyword.get_values(module_name.module_info(), :compile)
    [source] = Keyword.get_values(compile_infos, :source)
    source
  end

  defp get_line_number(_, nil), do: nil

  defp get_line_number(module, function_name) do
    {_, _, _, _, _, _, functions_list} = Code.fetch_docs(module)

    function_infos =
      functions_list
      |> Enum.find(fn {{type, name, _}, _, _, _, _} ->
        type == :function and name == function_name
      end)

    case function_infos do
      {_, anno, _, _, _} -> :erl_anno.line(anno)
      nil -> nil
    end
  end
end
