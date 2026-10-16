defmodule Noizu.Confluence.CommentsTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Comments

  test "create_footer/2 posts to /footer-comments" do
    client = basic_client(__MODULE__)

    attrs = %{
      "pageId" => "123",
      "body" => %{"representation" => "storage", "value" => "<p>looks good</p>"}
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/footer-comments"
      {body, conn} = read_json(conn)
      assert body == attrs
      respond_json(conn, 200, Map.put(attrs, "id", "900"))
    end)

    assert {:ok, %{"id" => "900"}} = Comments.create_footer(client, attrs)
  end

  test "footer lifecycle helpers hit their endpoints" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/footer-comments"
      respond_json(conn, 200, %{"results" => []})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/footer-comments/900"
      respond_json(conn, 200, %{"id" => "900"})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/wiki/api/v2/footer-comments/900"
      respond_json(conn, 200, %{"id" => "900"})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/wiki/api/v2/footer-comments/900"
      respond_json(conn, 200, %{})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/footer-comments/900/children"
      respond_json(conn, 200, %{"results" => []})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/footer-comments"
      respond_json(conn, 200, %{"results" => [%{"id" => "900"}]})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/blogposts/55/footer-comments"
      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} = Comments.list_footer(client)
    assert {:ok, %{"id" => "900"}} = Comments.get_footer(client, "900")

    assert {:ok, %{"id" => "900"}} =
             Comments.update_footer(client, "900", %{
               "body" => %{"representation" => "storage", "value" => "<p>edited</p>"}
             })

    assert {:ok, %{}} = Comments.delete_footer(client, "900")
    assert {:ok, %{"results" => []}} = Comments.footer_children(client, "900")
    assert {:ok, %{"results" => [%{"id" => "900"}]}} = Comments.list_footer_for_page(client, 123)
    assert {:ok, %{"results" => []}} = Comments.list_footer_for_blogpost(client, 55)
  end

  test "inline comments hit /inline-comments paths" do
    client = basic_client(__MODULE__)

    attrs = %{
      "pageId" => "123",
      "body" => %{"representation" => "storage", "value" => "<p>inline note</p>"},
      "inlineCommentProperties" => %{}
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/api/v2/inline-comments"
      {body, conn} = read_json(conn)
      assert body == attrs
      respond_json(conn, 200, Map.put(attrs, "id", "950"))
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/inline-comments/950"
      respond_json(conn, 200, %{"id" => "950"})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/inline-comments"
      respond_json(conn, 200, %{"results" => [%{"id" => "950"}]})
    end)

    assert {:ok, %{"id" => "950"}} = Comments.create_inline(client, attrs)
    assert {:ok, %{"id" => "950"}} = Comments.get_inline(client, "950")
    assert {:ok, %{"results" => [%{"id" => "950"}]}} = Comments.list_inline_for_page(client, 123)
  end
end
