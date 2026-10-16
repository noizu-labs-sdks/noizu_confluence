defmodule Noizu.Confluence.ErrorTest do
  use ExUnit.Case, async: true

  import Support

  alias Noizu.Confluence.{Error, Spaces}

  test "decodes the v2 error envelope (first errors[] entry)" do
    client = basic_client(__MODULE__)

    body = %{
      "errors" => [
        %{
          "status" => 404,
          "code" => "NOT_FOUND",
          "title" => "Not Found",
          "detail" => "No page with id 999"
        }
      ]
    }

    Req.Test.expect(__MODULE__, fn conn -> respond_json(conn, 404, body) end)

    assert {:error,
            %Error{
              status: 404,
              code: "NOT_FOUND",
              message: "Not Found",
              errors: [first]
            }} = Spaces.get(client, 999)

    assert first["detail"] == "No page with id 999"
  end

  test "decodes the v1 error envelope (statusCode/message/data)" do
    client = basic_client(__MODULE__)

    Req.Test.expect(__MODULE__, fn conn ->
      respond_json(conn, 400, %{
        "statusCode" => 400,
        "message" => "Bad CQL",
        "data" => %{"cql" => "..."}
      })
    end)

    assert {:error,
            %Error{
              status: 400,
              message: "Bad CQL",
              errors: %{"cql" => "..."}
            }} = Noizu.Confluence.Search.cql(client, "bogus AND")
  end

  test "keeps a truncated non-JSON body as the message" do
    client = basic_client(__MODULE__)
    html = String.duplicate("<html>upstream error</html>", 30)

    Req.Test.expect(__MODULE__, fn conn ->
      respond_raw(conn, 502, "text/html", html)
    end)

    assert {:error, %Error{status: 502, message: message, errors: []}} = Spaces.list(client)
    assert message =~ "<html>"
    assert String.length(message) <= 304
  end

  test "decodes transport failures with status nil" do
    error = Error.from_exception(RuntimeError.exception("connection refused"))

    assert error.status == nil
    assert error.code == "request_failed"
    assert error.message == "connection refused"
  end

  test "is raisable and formats a readable message" do
    error = Error.from_response(403, %{"errors" => [%{"code" => "FORBIDDEN", "title" => "nope"}]})

    assert Exception.message(error) == "confluence_error: status=403 code=FORBIDDEN nope"
  end
end
