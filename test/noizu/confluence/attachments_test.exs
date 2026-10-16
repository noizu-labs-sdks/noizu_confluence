defmodule Noizu.Confluence.AttachmentsTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Attachments

  test "list/2 and get/2 hit the v2 endpoints" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/attachments"
      assert query(conn)["mediaType"] == "image/png"
      respond_json(conn, 200, %{"results" => [%{"id" => "att-1"}]})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/attachments/att-1"
      respond_json(conn, 200, %{"id" => "att-1", "title" => "logo.png"})
    end)

    assert {:ok, %{"results" => [%{"id" => "att-1"}]}} =
             Attachments.list(client, params: %{mediaType: "image/png"})

    assert {:ok, %{"title" => "logo.png"}} = Attachments.get(client, "att-1")
  end

  test "list_for_page/3 hits /pages/{id}/attachments" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/api/v2/pages/123/attachments"
      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} = Attachments.list_for_page(client, 123)
  end

  test "upload/4 with a file path sends v1 multipart with the CSRF bypass header" do
    client = basic_client(__MODULE__)

    path =
      Path.join(
        System.tmp_dir!(),
        "noizu-confluence-test-#{System.unique_integer([:positive])}.txt"
      )

    File.write!(path, "attachment body")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/wiki/rest/api/content/123/child/attachment"
      assert header(conn, "x-atlassian-token") == "no-check"
      assert header(conn, "content-type") =~ "multipart/form-data"

      respond_json(conn, 200, %{"results" => [%{"id" => "att-2", "title" => Path.basename(path)}]})
    end)

    try do
      assert {:ok, %{"results" => [%{"id" => "att-2"}]}} =
               Attachments.upload(client, 123, {:path, path})
    after
      File.rm(path)
    end
  end

  test "upload/4 with raw data materializes a temp file and cleans up" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      respond_json(conn, 200, %{"results" => [%{"id" => "att-3"}]})
    end)

    assert {:ok, %{"results" => [%{"id" => "att-3"}]}} =
             Attachments.upload(client, 123, {:data, "notes.txt", "raw content"})

    leftovers =
      System.tmp_dir!()
      |> File.ls!()
      |> Enum.filter(&String.contains?(&1, "noizu-confluence-upload-"))

    assert leftovers == []
  end

  test "download/4 returns the raw binary" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/rest/api/content/123/child/attachment/att-1/download"

      conn
      |> Plug.Conn.put_resp_content_type("application/octet-stream")
      |> Plug.Conn.resp(200, <<0, 1, 2, 3>>)
    end)

    assert {:ok, <<0, 1, 2, 3>>} = Attachments.download(client, 123, "att-1")
  end
end
