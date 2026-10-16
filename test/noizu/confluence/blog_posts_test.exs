defmodule Noizu.Confluence.BlogPostsTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.BlogPosts

  test "create/2 posts the attrs as JSON" do
    client = basic_client(__MODULE__)

    attrs = %{
      "spaceId" => "10",
      "status" => "current",
      "title" => "News",
      "body" => %{"representation" => "storage", "value" => "<p>News</p>"}
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/blogposts"
      {body, conn} = read_json(conn)
      assert body == attrs
      respond_json(conn, 200, Map.put(attrs, "id", "55"))
    end)

    assert {:ok, %{"id" => "55"}} = BlogPosts.create(client, attrs)
  end

  test "update/4 fetches and increments version.number when omitted" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/blogposts/55"
      respond_json(conn, 200, %{"id" => "55", "version" => %{"number" => 2}})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/wiki/api/v2/blogposts/55"
      {body, conn} = read_json(conn)
      assert body["version"] == %{"number" => 3}
      assert body["id"] == "55"
      respond_json(conn, 200, %{"id" => "55", "version" => %{"number" => 3}})
    end)

    attrs = %{
      "title" => "News v2",
      "body" => %{"representation" => "storage", "value" => "<p>v2</p>"}
    }

    assert {:ok, %{"version" => %{"number" => 3}}} = BlogPosts.update(client, "55", attrs)
  end

  test "delete/2 and list_for_space/3 hit their endpoints" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/wiki/api/v2/blogposts/55"
      respond_json(conn, 200, %{})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/spaces/10/blogposts"
      respond_json(conn, 200, %{"results" => [%{"id" => "55"}]})
    end)

    assert {:ok, %{}} = BlogPosts.delete(client, "55")
    assert {:ok, %{"results" => [%{"id" => "55"}]}} = BlogPosts.list_for_space(client, 10)
  end
end
