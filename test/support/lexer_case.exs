defmodule MiniWikitext.LexerCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MiniWikitext.Lexer
      import unquote(__MODULE__)
    end
  end

  def assert_token_at(tokens, idx, kvs) when is_list(kvs) do
    token = Enum.fetch!(tokens, idx)

    Enum.each(kvs, fn {k, v} ->
      # 对 struct 用 Map.get/2 取字段即可
      assert Map.get(token, k) == v, """
      token[#{idx}] 字段 #{inspect(k)} 期望 #{inspect(v)}，实际 #{inspect(Map.get(token, k))}
      完整 token: #{inspect(token)}
      """
    end)

    token
  end
end
