defmodule Noizu.Confluence.ClientTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.{BlogPosts, Client, Error, Search, Spaces}

  describe "new/1" do
    test "builds a basic client with a normalized site" do
      client = Client.new(auth_mode: :basic, site: "example", email: "e@x.com", api_token: "tok")

      assert client.base_url == "https://example.atlassian.net/wiki"
      assert client.auth_mode == :basic
      assert client.max_retries == 3
      assert is_function(client.retry_sleep, 1)
    end

    test "strips scheme and trailing slash from :site" do
      client =
        Client.new(
          auth_mode: :basic,
          site: "https://example.atlassian.net/",
          email: "e@x.com",
          api_token: "tok"
        )

      assert client.base_url == "https://example.atlassian.net/wiki"
    end

    test "builds an oauth client with the api.atlassian.com base" do
      client = Client.new(auth_mode: :oauth, cloud_id: "abc-123", access_token: "tok")

      assert client.base_url ==
               "https://api.atlassian.com/ex/confluence/abc-123/wiki"
    end

    test "raises when basic auth fields are missing" do
      assert_raise ArgumentError, ~r/missing \[:site\]/, fn ->
        Client.new(auth_mode: :basic, email: "e@x.com", api_token: "tok")
      end
    end

    test "raises when oauth fields are missing" do
      assert_raise ArgumentError, ~r/missing \[:access_token\]/, fn ->
        Client.new(auth_mode: :oauth, cloud_id: "abc-123")
      end
    end

    test "raises on an unknown auth mode" do
      assert_raise ArgumentError, ~r/:basic or :oauth/, fn ->
        Client.new(auth_mode: :api_key, site: "example")
      end
    end
  end

  describe "basic auth requests" do
    test "hits https://<site>/wiki with a Basic authorization header" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.scheme == :https
        assert conn.host == "example.atlassian.net"
        assert conn.method == "GET"
        assert conn.request_path == "/wiki/api/v2/spaces"

        assert header(conn, "authorization") ==
                 "Basic " <> Base.encode64("user@example.com:test-api-token")

        respond_json(conn, 200, %{"results" => []})
      end)

      assert {:ok, %{"results" => []}} = Spaces.list(client)
    end
  end

  describe "oauth requests" do
    test "hits api.atlassian.com/ex/confluence/<cloudId>/wiki with a Bearer header" do
      client = oauth_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.host == "api.atlassian.com"

        assert conn.request_path ==
                 "/ex/confluence/a436116f-02ce-4620-840b-f5dd8d3f7861/wiki/api/v2/spaces"

        assert header(conn, "authorization") == "Bearer test-access-token"

        respond_json(conn, 200, %{"results" => []})
      end)

      assert {:ok, %{"results" => []}} = Spaces.list(client)
    end
  end

  describe "429 retry" do
    test "honors Retry-After and succeeds on a later attempt" do
      client =
        basic_client(__MODULE__,
          max_retries: 3,
          retry_sleep: fn ms -> send(self(), {:slept, ms}) end
        )

      Req.Test.expect(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_resp_header("retry-after", "2") |> respond_json(429, %{})
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        respond_json(conn, 200, %{"results" => [%{"id" => "1"}]})
      end)

      assert {:ok, %{"results" => [%{"id" => "1"}]}} = Spaces.list(client)
      assert_received {:slept, 2000}
    end

    test "backs off exponentially when Retry-After is absent" do
      client =
        basic_client(__MODULE__,
          max_retries: 2,
          retry_sleep: fn ms -> send(self(), {:slept, ms}) end
        )

      Req.Test.expect(__MODULE__, fn conn -> respond_json(conn, 429, %{}) end)
      Req.Test.expect(__MODULE__, fn conn -> respond_json(conn, 429, %{}) end)
      Req.Test.expect(__MODULE__, fn conn -> respond_json(conn, 200, %{"results" => []}) end)

      assert {:ok, %{"results" => []}} = Spaces.list(client)
      assert_received {:slept, 1000}
      assert_received {:slept, 2000}
    end

    test "stops at max_retries and returns the last 429 as an error" do
      client =
        basic_client(__MODULE__,
          max_retries: 1,
          retry_sleep: fn _ -> :ok end
        )

      Req.Test.expect(__MODULE__, fn conn -> respond_json(conn, 429, %{}) end)
      Req.Test.expect(__MODULE__, fn conn -> respond_json(conn, 429, %{}) end)

      assert {:error, %Error{status: 429}} = Spaces.list(client)
    end
  end

  describe "transport errors" do
    test "connection failures decode into %Error{}" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Error{status: nil, code: "request_failed"}} = Spaces.list(client)
    end
  end

  describe "query encoding" do
    test "ids and keys become repeated bare keys, not key[]= form" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_string == "ids=1&ids=2&keys=ENG&keys=OPS&limit=5"
        respond_json(conn, 200, %{"results" => [], "_links" => %{}})
      end)

      assert {:ok, _} =
               Spaces.list(client, params: %{ids: [1, 2], keys: ["ENG", "OPS"], limit: 5})
    end

    test "space-id becomes repeated bare keys" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_string == "space-id=10&space-id=20"
        respond_json(conn, 200, %{"results" => [], "_links" => %{}})
      end)

      assert {:ok, _} = BlogPosts.list(client, params: %{"space-id" => [10, 20]})
    end

    test "expand is comma-joined per its explode:false spec entry" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_string == "cql=type%3Dpage&expand=version%2Cspace"
        respond_json(conn, 200, %{"results" => []})
      end)

      assert {:ok, _} =
               Search.cql(client, "type=page", params: %{"expand" => ["version", "space"]})
    end

    test "nil values are dropped and booleans render true/false" do
      client = basic_client(__MODULE__)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_string == "exclude-templates=true&keys=ENG"
        respond_json(conn, 200, %{"results" => [], "_links" => %{}})
      end)

      assert {:ok, _} =
               Spaces.list(client,
                 params: %{limit: nil, keys: ["ENG"], "exclude-templates": true}
               )
    end
  end
end
