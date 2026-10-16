defmodule Noizu.Confluence.PagesTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Pages

  test "get/2 hits /pages/{id}" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123"
      respond_json(conn, 200, %{"id" => "123", "title" => "Hello", "version" => %{"number" => 7}})
    end)

    assert {:ok, %{"version" => %{"number" => 7}}} = Pages.get(client, "123")
  end

  test "create/2 posts the attrs as JSON" do
    client = basic_client(__MODULE__)

    attrs = %{
      "spaceId" => "10",
      "status" => "current",
      "title" => "Hello",
      "body" => %{"representation" => "storage", "value" => "<p>Hello</p>"}
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/pages"
      {body, conn} = read_json(conn)
      assert body == attrs
      respond_json(conn, 200, Map.put(attrs, "id", "123"))
    end)

    assert {:ok, %{"id" => "123"}} = Pages.create(client, attrs)
  end

  test "update/4 uses an explicitly provided version" do
    client = basic_client(__MODULE__)

    attrs = %{
      "title" => "Hello v2",
      "body" => %{"representation" => "storage", "value" => "<p>v2</p>"},
      "version" => %{"number" => 8, "message" => "manual"}
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/wiki/api/v2/pages/123"
      {body, conn} = read_json(conn)

      assert body == %{
               "id" => "123",
               "status" => "current",
               "title" => "Hello v2",
               "body" => %{"representation" => "storage", "value" => "<p>v2</p>"},
               "version" => %{"number" => 8, "message" => "manual"}
             }

      respond_json(conn, 200, %{"id" => "123", "version" => %{"number" => 8}})
    end)

    assert {:ok, %{"version" => %{"number" => 8}}} = Pages.update(client, "123", attrs)
  end

  test "update/4 fetches the current version and increments it when version is omitted" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/wiki/api/v2/pages/123"
      respond_json(conn, 200, %{"id" => "123", "version" => %{"number" => 7}})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      {body, conn} = read_json(conn)

      assert body["id"] == "123"
      assert body["status"] == "current"
      assert body["version"] == %{"number" => 8}

      respond_json(conn, 200, %{"id" => "123", "version" => %{"number" => 8}})
    end)

    attrs = %{
      "title" => "Hello v2",
      "body" => %{"representation" => "storage", "value" => "<p>v2</p>"}
    }

    assert {:ok, %{"version" => %{"number" => 8}}} = Pages.update(client, "123", attrs)
  end

  test "delete/2 hits DELETE /pages/{id}" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/wiki/api/v2/pages/123"
      respond_json(conn, 200, %{})
    end)

    assert {:ok, %{}} = Pages.delete(client, 123)
  end

  test "children/2 and versions/2 hit their subpaths" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/children"
      respond_json(conn, 200, %{"results" => [%{"id" => "200"}]})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/versions"
      respond_json(conn, 200, %{"results" => [%{"number" => 1}, %{"number" => 2}]})
    end)

    assert {:ok, %{"results" => [%{"id" => "200"}]}} = Pages.children(client, 123)

    assert {:ok, %{"results" => [%{"number" => 1}, %{"number" => 2}]}} =
             Pages.versions(client, 123)
  end

  test "list_for_space/3 hits /spaces/{id}/pages" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/spaces/10/pages"
      respond_json(conn, 200, %{"results" => [%{"id" => "123"}]})
    end)

    assert {:ok, %{"results" => [%{"id" => "123"}]}} = Pages.list_for_space(client, 10)
  end
end
