defmodule Noizu.Confluence.PropertiesTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.{Error, Properties}

  test "create/4 posts key/value to the parent path" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/pages/123/properties"
      {body, conn} = read_json(conn)
      assert body == %{"key" => "owner", "value" => "team-eng"}
      respond_json(conn, 200, %{"id" => "p1", "key" => "owner"})
    end)

    assert {:ok, %{"id" => "p1"}} =
             Properties.create(client, :page, 123, %{"key" => "owner", "value" => "team-eng"})
  end

  test "update/5 fetches and increments version.number when omitted" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/properties/p1"
      respond_json(conn, 200, %{"id" => "p1", "version" => %{"number" => 4}})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/wiki/api/v2/pages/123/properties/p1"
      {body, conn} = read_json(conn)
      assert body["version"] == %{"number" => 5}
      assert body["key"] == "owner"
      assert body["value"] == "team-eng-2"
      respond_json(conn, 200, %{"id" => "p1", "version" => %{"number" => 5}})
    end)

    assert {:ok, %{"version" => %{"number" => 5}}} =
             Properties.update(client, :page, 123, "p1", %{
               "key" => "owner",
               "value" => "team-eng-2"
             })
  end

  test "parent types route to their v2 collections" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/blogposts/55/properties"
      respond_json(conn, 200, %{"results" => []})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/spaces/10/properties"
      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} = Properties.list(client, :blogpost, 55)
    assert {:ok, %{"results" => []}} = Properties.list(client, :space, 10)
  end

  test "get/5 and delete/4 hit the property-id path" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/spaces/10/properties/p9"
      respond_json(conn, 200, %{"id" => "p9", "key" => "owner"})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/wiki/api/v2/spaces/10/properties/p9"
      respond_json(conn, 200, %{})
    end)

    assert {:ok, %{"key" => "owner"}} = Properties.get(client, :space, 10, "p9")
    assert {:ok, %{}} = Properties.delete(client, :space, 10, "p9")
  end

  test "an unknown parent type raises ArgumentError" do
    assert_raise ArgumentError, ~r/:page, :blogpost or :space/, fn ->
      Properties.list(basic_client(__MODULE__), :whiteboard, 1)
    end
  end

  test "update/5 surfaces a version_lookup_failed error when the property has no version" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      respond_json(conn, 200, %{"id" => "p1"})
    end)

    assert {:error, %Error{code: "version_lookup_failed"} = error} =
             Properties.update(client, :page, 123, "p1", %{"key" => "k", "value" => "v"})

    assert error.message =~ "could not read version.number"
  end
end
