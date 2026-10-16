defmodule Noizu.Confluence.UriTest do
  use ExUnit.Case, async: true

  alias Noizu.Confluence.Uri

  test "path_segment/1 keeps ordinary ids untouched" do
    assert Uri.path_segment(123) == "123"
    assert Uri.path_segment("att-1") == "att-1"

    assert Uri.path_segment("a436116f-02ce-4620-840b-f5dd8d3f7861") ==
             "a436116f-02ce-4620-840b-f5dd8d3f7861"
  end

  test "path_segment/1 encodes a crafted id into a single segment (T-004)" do
    segment = Uri.path_segment("1/../x?y=1")

    assert segment == "1%2F%2E%2E%2Fx%3Fy%3D1"
    assert URI.decode(segment) == "1/../x?y=1"
    refute segment =~ "/"
    refute segment =~ "?"
  end

  test "path_segment/1 escapes a bare dot-dot so it cannot climb the path" do
    assert Uri.path_segment("..") == "%2E%2E"
    refute Uri.path_segment("..") =~ ".."
  end

  test "path_segment/1 percent-encodes % itself so it cannot smuggle escapes" do
    assert Uri.path_segment("50%25") == "50%2525"
    assert URI.decode(Uri.path_segment("50%25")) == "50%25"
  end
end
