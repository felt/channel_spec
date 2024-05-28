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

    test "foo" do
      schema = %{
        type: :object,
        properties: %{
          b: %{type: :string},
          c: %{type: :string},
          x: %{type: :string},
          d: %{type: :string},
          electric_eel: %{type: :string},
          e: %{type: :string},
          h: %{type: :string},
          f: %{type: :string},
          g: %{type: :string},
          dog: %{type: :string},
          j: %{type: :string},
          k: %{type: :string},
          o: %{type: :string},
          jaguar: %{type: :string},
          l: %{type: :string},
          lemur: %{type: :string},
          u: %{type: :string},
          cuttle_fish: %{type: :string},
          m: %{type: :string},
          n: %{type: :string},
          ibex: %{type: :string},
          i: %{type: :string},
          hippopotamus: %{type: :string},
          y: %{type: :string},
          fox: %{type: :string},
          q: %{type: :string},
          a: %{type: :string},
          z: %{type: :string},
          koala: %{type: :string},
          r: %{type: :string},
          garden_snake: %{type: :string},
          s: %{type: :string},
          p: %{type: :string},
          bananas: %{type: :string},
          v: %{type: :string},
          t: %{type: :string},
          w: %{type: :string},
          apples: %{type: :string},
          one_of_list: [
            %{
              type: :object,
              properties: %{
                c: %{type: :string},
                b: %{type: :string},
                a: %{type: :string}
              }
            },
            %{
              type: :object,
              properties: %{
                f: %{type: :string},
                e: %{type: :string},
                d: %{type: :string}
              }
            }
          ]
        }
      }

      result =
        schema
        |> Serializer.to_schema()
        |> Serializer.to_string()

      assert """
             {
               "properties": {
                 "a": {
                   "type": "string"
                 },
                 "apples": {
                   "type": "string"
                 },
                 "b": {
                   "type": "string"
                 },
                 "bananas": {
                   "type": "string"
                 },
                 "c": {
                   "type": "string"
                 },
                 "cuttle_fish": {
                   "type": "string"
                 },
                 "d": {
                   "type": "string"
                 },
                 "dog": {
                   "type": "string"
                 },
                 "e": {
                   "type": "string"
                 },
                 "electric_eel": {
                   "type": "string"
                 },
                 "f": {
                   "type": "string"
                 },
                 "fox": {
                   "type": "string"
                 },
                 "g": {
                   "type": "string"
                 },
                 "garden_snake": {
                   "type": "string"
                 },
                 "h": {
                   "type": "string"
                 },
                 "hippopotamus": {
                   "type": "string"
                 },
                 "i": {
                   "type": "string"
                 },
                 "ibex": {
                   "type": "string"
                 },
                 "j": {
                   "type": "string"
                 },
                 "jaguar": {
                   "type": "string"
                 },
                 "k": {
                   "type": "string"
                 },
                 "koala": {
                   "type": "string"
                 },
                 "l": {
                   "type": "string"
                 },
                 "lemur": {
                   "type": "string"
                 },
                 "m": {
                   "type": "string"
                 },
                 "n": {
                   "type": "string"
                 },
                 "o": {
                   "type": "string"
                 },
                 "one_of_list": [
                   {
                     "properties": {
                       "a": {
                         "type": "string"
                       },
                       "b": {
                         "type": "string"
                       },
                       "c": {
                         "type": "string"
                       }
                     },
                     "type": "object"
                   },
                   {
                     "properties": {
                       "d": {
                         "type": "string"
                       },
                       "e": {
                         "type": "string"
                       },
                       "f": {
                         "type": "string"
                       }
                     },
                     "type": "object"
                   }
                 ],
                 "p": {
                   "type": "string"
                 },
                 "q": {
                   "type": "string"
                 },
                 "r": {
                   "type": "string"
                 },
                 "s": {
                   "type": "string"
                 },
                 "t": {
                   "type": "string"
                 },
                 "u": {
                   "type": "string"
                 },
                 "v": {
                   "type": "string"
                 },
                 "w": {
                   "type": "string"
                 },
                 "x": {
                   "type": "string"
                 },
                 "y": {
                   "type": "string"
                 },
                 "z": {
                   "type": "string"
                 }
               },
               "type": "object"
             }\
             """ == result
    end
  end
end
