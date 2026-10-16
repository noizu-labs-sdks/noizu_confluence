defmodule Support do
  @moduledoc false

  alias Noizu.Confluence.Client

  def basic_client(module, opts \\ []) do
    Client.new(
      [
        auth_mode: :basic,
        site: "example.atlassian.net",
        email: "user@example.com",
        api_token: "test-api-token",
        req_opts: [plug: {Req.Test, module}]
      ] ++ opts
    )
  end

  def oauth_client(module, opts \\ []) do
    Client.new(
      [
        auth_mode: :oauth,
        cloud_id: "a436116f-02ce-4620-840b-f5dd8d3f7861",
        access_token: "test-access-token",
        req_opts: [plug: {Req.Test, module}]
      ] ++ opts
    )
  end

  def respond_json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  def respond_raw(conn, status, content_type, body) do
    conn
    |> Plug.Conn.put_resp_content_type(content_type)
    |> Plug.Conn.resp(status, body)
  end

  def read_json(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(raw), conn}
  end

  def header(conn, name) do
    case Plug.Conn.get_req_header(conn, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  def query(conn) do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Map.get(:query_params)
  end
end
