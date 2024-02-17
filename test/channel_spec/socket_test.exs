defmodule ChannelSpec.SocketTest do
  use ExUnit.Case, async: true
  use Mneme

  def make_mod() do
    String.to_atom("Elixir.Test#{System.unique_integer([:positive])}")
  end

  describe "channel/3" do
    setup do
      mod = make_mod()

      {:ok, mod: mod}
    end

    test "stores the channel", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel("foo", __MODULE__.MyChannel)
      end

      assert channels = mod.__registered_channels__()

      assert channels == [{"foo", :"#{mod}.MyChannel", []}]
    end

    test "stores the channel with assigns", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel("foo", __MODULE__.MyChannel, assigns: [foo: "bar"])
      end

      assert channels = mod.__registered_channels__()

      assert channels == [{"foo", :"#{mod}.MyChannel", [assigns: [foo: "bar"]]}]
    end

    test "supports channel topic patterns", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel("foo:*", __MODULE__.MyChannel)
        channel("foo:{user_id}", __MODULE__.MyChannel)
      end

      assert channels = mod.__registered_channels__()

      assert channels == [
               {"foo:{user_id}", :"#{mod}.MyChannel", []},
               {"foo:{string}", :"#{mod}.MyChannel", []}
             ]
    end
  end

  describe "__socket_tree__/0" do
    setup do
      mod = make_mod()

      {:ok, mod: mod}
    end

    test "builds the socket tree", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel("foo", __MODULE__.MyChannel)
      end

      assert tree = mod.__socket_tree__()

      assert tree == %{
               channels: %{"foo" => %{messages: %{}, subscriptions: %{}}},
               definitions: %{}
             }
    end

    test "builds the socket tree with multiple channels", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations
      end

      defmodule :"#{mod}.MyOtherChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
        channel "bar", __MODULE__.MyOtherChannel
      end

      assert tree = mod.__socket_tree__()

      assert tree == %{
               channels: %{
                 "bar" => %{messages: %{}, subscriptions: %{}},
                 "foo" => %{messages: %{}, subscriptions: %{}}
               },
               definitions: %{}
             }
    end

    test "registers channel operations", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{type: :string}

        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert tree = mod.__socket_tree__()

      assert %{
               channels: %{
                 "foo" => %{
                   messages: %{
                     "foo" => %{
                       schema: %{
                         payload: %{
                           type: :string
                         }
                       }
                     }
                   }
                 }
               }
             } =
               tree
    end

    test "registers channel subscriptions", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        subscription "foo", %{type: :string}
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert tree = mod.__socket_tree__()

      auto_assert %{
                    channels: %{"foo" => %{subscriptions: %{"foo" => %{type: :string}}}}
                  } <- tree
    end

    test "registers $ref schema definitions", %{mod: mod} do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{type: :string}
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert tree = mod.__socket_tree__()

      auto_assert %{
                    channels: %{
                      "foo" => %{
                        messages: %{
                          "foo" => %{
                            schema: %{payload: %{"$ref": "#/definitions/Schema"}}
                          }
                        }
                      }
                    },
                    definitions: %{"Schema" => %{type: :string}}
                  } <- tree
    end

    test "resolves circular references in schemas", %{mod: mod} do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{
            type: :object,
            properties: %{
              foo: %{"$ref": __MODULE__}
            }
          }
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert tree = mod.__socket_tree__()

      auto_assert %{
                    channels: %{
                      "foo" => %{
                        messages: %{
                          "foo" => %{
                            schema: %{payload: %{"$ref": "#/definitions/Schema"}}
                          }
                        }
                      }
                    },
                    definitions: %{
                      "Schema" => %{
                        properties: %{
                          foo: %{"$ref": "#/definitions/Schema"}
                        },
                        type: :object
                      }
                    }
                  } <- tree
    end
  end

  describe "__socket_schemas__/0" do
    setup do
      mod = make_mod()

      {:ok, mod: mod}
    end

    test "builds the socket schemas", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{type: :string}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert schemas = mod.__socket_schemas__()

      auto_assert %{
                    "channels" => %{
                      "foo" => %{
                        "messages" => %{
                          "foo" => %{
                            "payload" => %Xema{schema: %Xema.Schema{type: :string}}
                          }
                        }
                      }
                    }
                  } <- schemas
    end

    test "builds the socket schemas with multiple channels", %{mod: mod} do
      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{type: :string}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}.MyOtherChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "bar", payload: %{type: :string}
        handle "bar", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
        channel "bar:*", __MODULE__.MyOtherChannel
      end

      assert schemas = mod.__socket_schemas__()

      auto_assert %{
                    "channels" => %{
                      "bar:{string}" => %{
                        "messages" => %{
                          "bar" => %{
                            "payload" => %Xema{schema: %Xema.Schema{type: :string}}
                          }
                        }
                      },
                      "foo" => %{
                        "messages" => %{
                          "foo" => %{
                            "payload" => %Xema{schema: %Xema.Schema{type: :string}}
                          }
                        }
                      }
                    }
                  } <- schemas
    end

    test "stores $ref in definitions", %{mod: mod} do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{type: :string}
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert schemas = mod.__socket_schemas__()

      auto_assert %{
                    "channels" => %{
                      "foo" => %{
                        "messages" => %{
                          "foo" => %{
                            "payload" => %Xema{
                              refs: %{"#/definitions/Schema" => %Xema.Schema{type: :string}},
                              schema: %Xema.Schema{
                                ref: %Xema.Ref{pointer: "#/definitions/Schema"}
                              }
                            }
                          }
                        }
                      }
                    }
                  } <- schemas
    end

    test "stores $ref in the xema schemas", %{mod: mod} do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{type: :string}
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert schemas = mod.__socket_schemas__()

      auto_assert %{
                    "channels" => %{
                      "foo" => %{
                        "messages" => %{
                          "foo" => %{
                            "payload" => %Xema{
                              schema: %Xema.Schema{
                                ref: %Xema.Ref{pointer: "#/definitions/Schema"}
                              }
                            }
                          }
                        }
                      }
                    }
                  } <- schemas
    end

    test "handles circular $ref", %{mod: mod} do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{
            type: :object,
            properties: %{
              foo: %{"$ref": __MODULE__}
            }
          }
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert schemas = mod.__socket_schemas__()

      auto_assert %{
                    "channels" => %{
                      "foo" => %{
                        "messages" => %{
                          "foo" => %{
                            "payload" => %Xema{
                              refs: %{
                                "#/definitions/Schema" => %Xema.Schema{
                                  keys: :strings,
                                  properties: %{
                                    "foo" => %Xema.Schema{
                                      ref: %Xema.Ref{pointer: "#/definitions/Schema"}
                                    }
                                  },
                                  type: :map
                                }
                              },
                              schema: %Xema.Schema{
                                ref: %Xema.Ref{pointer: "#/definitions/Schema"}
                              }
                            }
                          }
                        }
                      }
                    }
                  } <- schemas
    end

    test "generated schemas can be used for validation", %{mod: mod} do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{type: :integer}
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      assert schemas = mod.__socket_schemas__()

      foo_schema = schemas["channels"]["foo"]["messages"]["foo"]["payload"]

      assert :ok = Xema.validate(foo_schema, 123)
      assert {:error, _} = Xema.validate(foo_schema, "123")
    end
  end

  describe "using/1" do
    setup do
      mod = make_mod()

      %{mod: mod}
    end

    @tag :tmp_dir
    test "if a schema file path is provided, the schema will be written to that path", %{
      mod: mod,
      tmp_dir: tmp_dir
    } do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{type: :integer}
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end

        subscription "sub", %{type: :integer}
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket, schema_path: Path.join(tmp_dir, "schema.json")

        channel "foo", __MODULE__.MyChannel, schema_file: Path.join(tmp_dir, "schema.json")
      end

      saved_json = Path.join(tmp_dir, "schema.json") |> File.read!() |> Jason.decode!()

      auto_assert %{
                    "channels" => %{
                      "foo" => %{
                        "messages" => %{
                          "foo" => %{"payload" => %{"$ref" => "#/definitions/Schema"}}
                        },
                        "subscriptions" => %{"sub" => %{"type" => "integer"}}
                      }
                    },
                    "definitions" => %{"Schema" => %{"type" => "integer"}}
                  } <- saved_json
    end

    @tag :tmp_dir
    test "if no schema file path is provided, the schema will not be written to a file", %{
      mod: mod,
      tmp_dir: tmp_dir
    } do
      defmodule :"#{mod}.Schema" do
        def schema() do
          %{type: :integer}
        end
      end

      defmodule :"#{mod}.MyChannel" do
        use ChannelHandler.Router
        use ChannelSpec.Operations

        operation "foo", payload: %{"$ref": :"#{mod}.Schema"}
        handle "foo", fn _params, _context, socket -> {:noreply, socket} end
      end

      defmodule :"#{mod}" do
        use ChannelSpec.Socket

        channel "foo", __MODULE__.MyChannel
      end

      refute File.exists?(Path.join(tmp_dir, "schema.json"))
    end
  end
end
