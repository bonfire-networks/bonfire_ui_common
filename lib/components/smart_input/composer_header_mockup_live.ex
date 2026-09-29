defmodule Bonfire.UI.Common.ComposerHeaderMockupLive do
  @moduledoc """
  TEMPORARY, UI MOCK-UP ONLY, nothing is wired: the composer header as one sentence, "as [who] · in [where] · visible to [whom]", for screenshots while the design for issues #2352 and #2303 is discussed. Remove once decided.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop context_group, :any, default: nil
end
