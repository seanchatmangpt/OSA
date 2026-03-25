defmodule OptimalSystemAgent.Protocol.CloudEventTest do
  @moduledoc """
  Unit tests for Protocol.CloudEvent module.

  Tests CloudEvent v1.0.2 envelope encode/decode/conversion.
  Pure functions, no mocks.
  """

  use ExUnit.Case, async: true

  alias OptimalSystemAgent.Protocol.CloudEvent

  @moduletag :capture_log

  describe "new/1" do
    test "creates CloudEvent from attribute map" do
      attrs = %{
        type: "com.example.test",
        source: "/test/source",
        data: %{message: "hello"}
      }
      event = CloudEvent.new(attrs)
      assert event.type == "com.example.test"
      assert event.source == "/test/source"
      assert event.data == %{message: "hello"}
    end

    test "raises KeyError when type is missing" do
      attrs = %{source: "/test"}
      assert_raise KeyError, fn -> CloudEvent.new(attrs) end
    end

    test "raises KeyError when source is missing" do
      attrs = %{type: "test"}
      assert_raise KeyError, fn -> CloudEvent.new(attrs) end
    end

    test "generates ID when not provided" do
      attrs = %{type: "test", source: "/test"}
      event = CloudEvent.new(attrs)
      assert event.id != nil
      assert event.id != ""
    end

    test "uses provided ID when available" do
      attrs = %{type: "test", source: "/test", id: "custom-id"}
      event = CloudEvent.new(attrs)
      assert event.id == "custom-id"
    end

    test "sets default specversion to 1.0" do
      attrs = %{type: "test", source: "/test"}
      event = CloudEvent.new(attrs)
      assert event.specversion == "1.0"
    end

    test "sets default datacontenttype to application/json" do
      attrs = %{type: "test", source: "/test"}
      event = CloudEvent.new(attrs)
      assert event.datacontenttype == "application/json"
    end

    test "converts atom type to string" do
      attrs = %{type: :atom_type, source: :atom_source}
      event = CloudEvent.new(attrs)
      assert event.type == "atom_type"
      assert event.source == "atom_source"
    end

    test "accepts string keys in attrs map" do
      attrs = %{"type" => "test", "source" => "/test"}
      event = CloudEvent.new(attrs)
      assert event.type == "test"
      assert event.source == "/test"
    end

    test "sets time from DateTime" do
      now = DateTime.utc_now()
      attrs = %{type: "test", source: "/test", time: now}
      event = CloudEvent.new(attrs)
      assert event.time != nil
    end

    test "sets subject when provided" do
      attrs = %{type: "test", source: "/test", subject: "test-subject"}
      event = CloudEvent.new(attrs)
      assert event.subject == "test-subject"
    end
  end

  describe "encode/1" do
    test "encodes valid CloudEvent to JSON" do
      event = %CloudEvent{
        type: "test",
        source: "/source",
        id: "test-id",
        time: "2024-01-01T00:00:00Z",
        data: %{key: "value"}
      }
      assert {:ok, json} = CloudEvent.encode(event)
      assert is_binary(json)
      assert String.contains?(json, "\"type\"")
      assert String.contains?(json, "\"source\"")
    end

    test "returns error when type is nil" do
      event = %CloudEvent{type: nil, source: "/test"}
      assert {:error, "type is required"} = CloudEvent.encode(event)
    end

    test "returns error when source is nil" do
      event = %CloudEvent{type: "test", source: nil}
      assert {:error, "source is required"} = CloudEvent.encode(event)
    end

    test "includes subject in JSON when present" do
      event = %CloudEvent{
        type: "test",
        source: "/source",
        id: "test-id",
        subject: "test-subject"
      }
      assert {:ok, json} = CloudEvent.encode(event)
      assert String.contains?(json, "subject")
    end

    test "includes data in JSON" do
      event = %CloudEvent{
        type: "test",
        source: "/source",
        id: "test-id",
        data: %{message: "hello"}
      }
      assert {:ok, json} = CloudEvent.encode(event)
      assert String.contains?(json, "data")
    end
  end

  describe "decode/1" do
    test "decodes JSON string to CloudEvent struct" do
      json = ~s({"type":"test","source":"/source","id":"test-id"})
      assert {:ok, event} = CloudEvent.decode(json)
      assert event.type == "test"
      assert event.source == "/source"
      assert event.id == "test-id"
    end

    test "decodes map to CloudEvent struct" do
      map = %{"type" => "test", "source" => "/source", "id" => "test-id"}
      assert {:ok, event} = CloudEvent.decode(map)
      assert event.type == "test"
    end

    test "returns error when type is missing" do
      json = ~s({"source":"/source"})
      assert {:error, "type is required"} = CloudEvent.decode(json)
    end

    test "returns error when type is empty string" do
      json = ~s({"type":"","source":"/source"})
      assert {:error, "type is required"} = CloudEvent.decode(json)
    end

    test "returns error when source is missing" do
      json = ~s({"type":"test"})
      assert {:error, "source is required"} = CloudEvent.decode(json)
    end

    test "returns error when source is empty string" do
      json = ~s({"type":"test","source":""})
      assert {:error, "source is required"} = CloudEvent.decode(json)
    end

    test "returns error for invalid JSON" do
      json = "not valid json"
      assert {:error, _reason} = CloudEvent.decode(json)
    end

    test "decodes subject when present" do
      json = ~s({"type":"test","source":"/source","subject":"test-subject"})
      assert {:ok, event} = CloudEvent.decode(json)
      assert event.subject == "test-subject"
    end

    test "decodes data when present" do
      json = ~s({"type":"test","source":"/source","data":{"key":"value"}})
      assert {:ok, event} = CloudEvent.decode(json)
      assert event.data == %{"key" => "value"}
    end

    test "generates ID when not present in JSON" do
      json = ~s({"type":"test","source":"/source"})
      assert {:ok, event} = CloudEvent.decode(json)
      assert event.id != nil
      assert event.id != ""
    end
  end

  describe "struct fields" do
    test "has specversion field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :specversion)
    end

    test "has type field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :type)
    end

    test "has source field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :source)
    end

    test "has subject field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :subject)
    end

    test "has id field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :id)
    end

    test "has time field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :time)
    end

    test "has datacontenttype field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :datacontenttype)
    end

    test "has data field" do
      event = %CloudEvent{}
      assert Map.has_key?(event, :data)
    end
  end

  describe "edge cases" do
    test "handles unicode in type" do
      attrs = %{type: "测试类型", source: "/test"}
      event = CloudEvent.new(attrs)
      assert event.type == "测试类型"
    end

    test "handles unicode in source" do
      attrs = %{type: "test", source: "/测试/路径"}
      event = CloudEvent.new(attrs)
      assert event.source == "/测试/路径"
    end

    test "handles empty data" do
      attrs = %{type: "test", source: "/test", data: nil}
      event = CloudEvent.new(attrs)
      assert event.data == nil
    end

    test "handles complex data structure" do
      data = %{nested: %{key: "value"}, list: [1, 2, 3]}
      attrs = %{type: "test", source: "/test", data: data}
      event = CloudEvent.new(attrs)
      assert event.data == data
    end
  end

  describe "integration" do
    test "full encode/decode roundtrip" do
      original = CloudEvent.new(%{
        type: "test.event",
        source: "/test/source",
        subject: "test-subject",
        data: %{message: "hello"}
      })

      assert {:ok, json} = CloudEvent.encode(original)
      assert {:ok, decoded} = CloudEvent.decode(json)

      assert decoded.type == original.type
      assert decoded.source == original.source
      assert decoded.subject == original.subject
      # JSON decode returns string keys - this is expected behavior
      assert decoded.data == %{"message" => "hello"}
    end
  end
end
