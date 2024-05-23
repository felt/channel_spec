defmodule ChannelSpec.SerializerTest do
  use ExUnit.Case, async: true

  describe "to_schema/1" do
    test "converts an elixir schema to a json schema map" do
      schema = %{
        type: :object,
        properties: %{
          string: %{type: :string},
          enum: %{type: :string, enum: [:foo, :bar]},
          one_of_array: %{
            type: :array,
            items: %{
              one_of: [
                %{type: :string},
                %{type: :number}
              ]
            }
          }
        }
      }

      converted_schema =
        schema
        |> Serializer.to_schema()
        |> Serializer.to_string()
        |> Jason.decode!()

      assert converted_schema == %{
               "properties" => %{
                 "enum" => %{"enum" => ["foo", "bar"], "type" => "string"},
                 "one_of_array" => %{
                   "items" => %{"one_of" => [%{"type" => "string"}, %{"type" => "number"}]},
                   "type" => "array"
                 },
                 "string" => %{"type" => "string"}
               },
               "type" => "object"
             }
    end
  end
end
