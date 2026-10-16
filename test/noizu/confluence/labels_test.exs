defmodule Noizu.Confluence.LabelsTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Labels

  test "list_for_page/3 uses the v2 endpoint" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/labels"
      respond_json(conn, 200, %{"results" => [%{"name" => "docs", "prefix" => "global"}]})
    end)

    assert {:ok, %{"results" => [%{"name" => "docs"}]}} = Labels.list_for_page(client, 123)
  end

  test "add/4 wraps bare strings with the global prefix and posts to v1" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/rest/api/content/123/label"
      {body, conn} = read_json(conn)

      assert body == [
               %{"prefix" => "global", "name" => "docs"},
               %{"prefix" => "global", "name" => "eng"}
             ]

      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{}} = Labels.add(client, "123", ["docs", "eng"])
  end

  test "add/4 passes label maps through verbatim" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      {body, conn} = read_json(conn)
      assert body == [%{"prefix" => "team", "name" => "platform"}]
      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{}} = Labels.add(client, 123, %{"prefix" => "team", "name" => "platform"})
  end

  test "remove/4 deletes via v1 with the name query param" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/wiki/rest/api/content/123/label"
      assert query(conn) == %{"name" => "docs"}
      respond_json(conn, 200, %{})
    end)

    assert {:ok, %{}} = Labels.remove(client, "123", "docs")
  end

  test "list_for_blogpost/3 and list_for_space/3 use the v2 endpoints" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/blogposts/55/labels"
      respond_json(conn, 200, %{"results" => []})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/spaces/10/labels"
      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} = Labels.list_for_blogpost(client, 55)
    assert {:ok, %{"results" => []}} = Labels.list_for_space(client, 10)
  end
end
