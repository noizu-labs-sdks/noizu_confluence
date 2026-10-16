defmodule Noizu.Confluence.PaginationTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.{Error, Pagination, Pages}

  describe "next_path/2" do
    test "prefers body _links.next and strips the /wiki prefix" do
      body = %{"results" => [], "_links" => %{"next" => "/wiki/api/v2/pages?cursor=abc"}}

      assert Pagination.next_path(body) == "/api/v2/pages?cursor=abc"
    end

    test "normalizes absolute URLs to path + query" do
      body = %{
        "results" => [],
        "_links" => %{"next" => "https://example.atlassian.net/wiki/rest/api/search?cursor=xyz"}
      }

      assert Pagination.next_path(body) == "/rest/api/search?cursor=xyz"
    end

    test "returns nil when the body has no next link and no response is given" do
      assert Pagination.next_path(%{"results" => []}) == nil
      assert Pagination.next_path(%{"results" => [], "_links" => %{}}) == nil
    end

    test "falls back to the Link header when the body lacks _links.next" do
      response = %Req.Response{
        status: 200,
        headers: %{"link" => ["</wiki/api/v2/pages?cursor=hdr>; rel=\"next\""]}
      }

      assert Pagination.next_path(%{"results" => []}, response) == "/api/v2/pages?cursor=hdr"
    end

    test "returns nil when neither body nor header advertise a next page" do
      response = %Req.Response{status: 200, headers: %{}}
      assert Pagination.next_path(%{"results" => []}, response) == nil
    end
  end

  describe "item_stream/3" do
    test "follows body cursors across pages and yields every item" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/wiki/api/v2/pages"
        assert query(conn) == %{"limit" => "2"}

        respond_json(conn, 200, %{
          "results" => [%{"id" => "1"}, %{"id" => "2"}],
          "_links" => %{"next" => "/wiki/api/v2/pages?limit=2&cursor=abc"}
        })
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/wiki/api/v2/pages"
        assert query(conn)["cursor"] == "abc"

        respond_json(conn, 200, %{
          "results" => [%{"id" => "3"}],
          "_links" => %{}
        })
      end)

      ids =
        client
        |> Pages.list_stream(params: %{limit: 2})
        |> Enum.map(& &1["id"])

      assert ids == ["1", "2", "3"]
    end

    test "raises %Error{} when a page fetch fails mid-stream" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        respond_json(conn, 200, %{
          "results" => [%{"id" => "1"}],
          "_links" => %{"next" => "/api/v2/pages?cursor=abc"}
        })
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        respond_json(conn, 500, %{"message" => "boom"})
      end)

      assert_raise Error, ~r/confluence_error: status=500 boom/, fn ->
        client |> Pages.list_stream() |> Enum.to_list()
      end
    end
  end
end
