defmodule Noizu.Confluence.AttachmentsTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Attachments
  alias Noizu.Confluence.Error

  defp upload_files(suffix) do
    System.tmp_dir!()
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "noizu-confluence-upload-"))
    |> Enum.filter(&String.ends_with?(&1, suffix))
  end

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

    leftovers = upload_files("-notes.txt")

    assert leftovers == []
  end

  test "upload/4 with a traversal filename writes only inside tmp_dir and keeps the original multipart filename (T-002)" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ ~s(filename="../../etc/x")

      names = upload_files("-x")

      assert length(names) == 1
      assert [name] = names
      assert name =~ ~r/^noizu-confluence-upload-[0-9a-f]{12}-x$/
      assert File.exists?(Path.join(System.tmp_dir!(), name))
      refute File.exists?(Path.join(System.tmp_dir!(), "etc"))

      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, %{"results" => []}} =
             Attachments.upload(client, 123, {:data, "../../etc/x", "content"})

    assert upload_files("-x") == []
  end

  test "upload/4 materializes the temp file with owner-only 0600 permissions (T-003)" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert [name] = upload_files("-secret.bin")
      stat = File.stat!(Path.join(System.tmp_dir!(), name))
      assert Bitwise.band(stat.mode, 0o777) == 0o600

      respond_json(conn, 200, %{"results" => []})
    end)

    assert {:ok, _} = Attachments.upload(client, 123, {:data, "secret.bin", "raw content"})

    assert upload_files("-secret.bin") == []
  end

  describe "upload/4 filename validation (T-002)" do
    test "rejects empty, dot, dot-dot and NUL-containing filenames" do
      client = basic_client(__MODULE__)

      for bad <- ["", ".", "..", "evil\0name", "dir/subdir/.."] do
        assert {:error, %Error{code: "invalid_filename"}} =
                 Attachments.upload(client, 123, {:data, bad, "content"})
      end

      refute Enum.any?(File.ls!(System.tmp_dir!()), &String.contains?(&1, "evil"))
    end
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
