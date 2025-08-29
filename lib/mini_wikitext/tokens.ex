defmodule MiniWikitext.Tokens do
  alias MiniWikitext.Tokens.Token

  # Unified create_token API for tag-based tokens
  def create_token(type, raw, tag, options) do
    %Token{
      lineno: 1,
      column: 1,
      type: type,
      raw: raw,
      tag: tag,
      options: options
    }
  end

  # Handle simple tokens without options  
  def create_token(type, raw \\ "") do
    %Token{
      lineno: 1,
      column: 1,
      type: type,
      raw: raw,
      tag: nil,
      options: nil
    }
  end

  def set_token_pos(token, lineno, column) do
    %{token | lineno: lineno, column: column}
  end

  def inspect_token(%Token{lineno: lineno, column: column, type: type, raw: raw}) do
    raw_str =
      if raw do
        " " <> inspect(raw)
      else
        ""
      end

    "[Token:#{lineno}:#{column} " <>
      "\e[32m#{type}\e[0m" <>
      "\e[33m#{raw_str}\e[0m" <>
      "]"
  end
end
