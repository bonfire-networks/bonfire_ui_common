defmodule Bonfire.UI.Common.DeterministicDomIdTest do
  use ExUnit.Case, async: true

  @moduletag :backend

  import Bonfire.UI.Common,
    only: [deterministic_dom_id: 2, deterministic_dom_id: 3, deterministic_dom_id: 4]

  doctest Bonfire.UI.Common, only: [deterministic_dom_id: 4], import: true

  # Two multiselects on one page (eg. the `:provider` and `:tag_ids` filters on the tasks page) differ only by an atom `form_input_name`, so atoms must count towards the id or LiveView raises on the duplicate.
  test "atom parts are kept, so siblings differing only by an atom get distinct ids" do
    provider = deterministic_dom_id("multiselect", nil, :provider, nil)
    tags = deterministic_dom_id("multiselect", nil, :tag_ids, nil)

    assert provider == "multiselect_provider"
    assert tags == "multiselect_tag_ids"
  end

  test "number parts are kept" do
    assert deterministic_dom_id("row", 42) == "row_42"
  end

  test "nil parts are skipped" do
    assert deterministic_dom_id("multiselect", nil, nil, nil) == "multiselect"
  end
end
