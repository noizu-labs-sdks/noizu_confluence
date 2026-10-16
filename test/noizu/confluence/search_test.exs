defmodule Noizu.Confluence.SearchTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Search

  test "cql/3 hits the v1 search endpoint with cql in the query" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.host == "example.atlassian.net"
      assert conn.request_path == "/wiki/rest/api/search"

      q = query(conn)
      assert q["cql"] == "type=page AND space=ENG"
      assert q["limit"] == "25"

      respond_json(conn, 200, %{
        "results" => [%{"content" => %{"id" => "123"}}],
        "size" => 1,
        "totalSize" => 1,
        "_links" => %{}
      })
    end)

    assert {:ok, %{"results" => [%{"content" => %{"id" => "123"}}]}} =
             Search.cql(client, "type=page AND space=ENG", params: %{limit: 25})
  end

  test "cql_stream/3 follows v1 cursors across pages" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/rest/api/search"
      assert query(conn)["cql"] == "type=page"

      respond_json(conn, 200, %{
        "results" => [%{"content" => %{"id" => "1"}}, %{"content" => %{"id" => "2"}}],
        "_links" => %{"next" => "/rest/api/search?cql=type%3Dpage&cursor=tok"}
      })
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/rest/api/search"
      assert query(conn)["cursor"] == "tok"

      respond_json(conn, 200, %{
        "results" => [%{"content" => %{"id" => "3"}}],
        "_links" => %{}
      })
    end)

    ids =
      client
      |> Search.cql_stream("type=page")
      |> Enum.map(& &1["content"]["id"])

    assert ids == ["1", "2", "3"]
  end
end
