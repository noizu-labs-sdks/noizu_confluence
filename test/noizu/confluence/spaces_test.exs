defmodule Noizu.Confluence.SpacesTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Spaces

  test "list/2 returns the raw response map" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/spaces"
      assert query(conn) == %{"limit" => "5", "type" => "global"}

      respond_json(conn, 200, %{"results" => [%{"id" => "10", "key" => "ENG"}], "_links" => %{}})
    end)

    assert {:ok, %{"results" => [%{"id" => "10"}]}} =
             Spaces.list(client, params: %{limit: 5, type: "global"})
  end

  test "get/2 hits /spaces/{id}" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/spaces/10"
      respond_json(conn, 200, %{"id" => "10", "name" => "Engineering"})
    end)

    assert {:ok, %{"name" => "Engineering"}} = Spaces.get(client, 10)
  end

  test "create/2 posts the attrs as JSON" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/spaces"
      {body, conn} = read_json(conn)
      assert body == %{"name" => "Engineering", "key" => "ENG"}

      respond_json(conn, 200, %{"id" => "10", "name" => "Engineering", "key" => "ENG"})
    end)

    assert {:ok, %{"key" => "ENG"}} =
             Spaces.create(client, %{"name" => "Engineering", "key" => "ENG"})
  end
end
