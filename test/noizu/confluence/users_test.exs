defmodule Noizu.Confluence.UsersTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.Users

  test "current/2 hits the v1 current-user endpoint" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/rest/api/user/current"
      respond_json(conn, 200, %{"accountId" => "acc-1", "displayName" => "Tyna"})
    end)

    assert {:ok, %{"accountId" => "acc-1"}} = Users.current(client)
  end

  test "get/3 passes accountId as the query param" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/wiki/rest/api/user"
      assert query(conn) == %{"accountId" => "acc-2"}
      respond_json(conn, 200, %{"accountId" => "acc-2"})
    end)

    assert {:ok, %{"accountId" => "acc-2"}} = Users.get(client, "acc-2")
  end
end
