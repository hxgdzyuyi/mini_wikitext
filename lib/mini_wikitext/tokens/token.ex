defmodule MiniWikitext.Tokens.Token do
  defstruct lineno: 0,
            column: 0,
            type: nil,
            raw: nil,
            tag: nil,
            options: %{}
end
