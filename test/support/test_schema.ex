defmodule ChannelSpec.SocketTest.LotsOfRefsSchema do
  @moduledoc """
  This specific setup causes `__unresolved_refs` to get into a state that makes the schema
  fail to compile. The PR in which this file was introduced switches from `Map.update!` to
  `Map.update` with a default and generates a valid schema.
  """

  defmodule Base do
    @behaviour ChannelSpec.Schema

    def schema() do
      %{
        type: :object,
        properties: %{
          foo: %{"$ref": ChannelSpec.SocketTest.LotsOfRefsSchema.Foo},
          bar: %{type: :array, items: [%{"$ref": ChannelSpec.SocketTest.LotsOfRefsSchema.Bar}]},
          flim: %{ type: :array, items: [%{"$ref": ChannelSpec.SocketTest.LotsOfRefsSchema.Flim}] }
        },
        additionalProperties: false
      }
    end
  end

  defmodule Flim do
    @behaviour ChannelSpec.Schema

    def schema() do
      %{
        type: :object,
        properties: %{
          flam: %{
            oneOf: [
              %{type: :null},
              %{"$ref": ChannelSpec.SocketTest.LotsOfRefsSchema.Flam}
            ]
          }
        },
        additionalProperties: false
      }
    end
  end

  defmodule Foo do
    def schema() do
      %{ oneOf: [ %{type: :null}, %{type: :string} ] }
    end
  end

  defmodule Bar do
    def schema() do
      %{type: :object, properties: %{baz: %{"$ref": ChannelSpec.SocketTest.LotsOfRefsSchema.Baz}}}
    end
  end

  defmodule Baz do
    def schema() do
      %{oneOf: [%{type: :string}, %{type: :null}]}
    end
  end
end

defmodule ChannelSpec.SocketTest.LotsOfRefsSchema.Flam do
  def schema() do
    %{
      type: :object,
      properties: %{
        whatever: %{
          type: :array,
          items: [ %{ type: :array, items: [%{type: :string}] }
          ]
        }
      },
      additionalProperties: false
    }
  end
end
