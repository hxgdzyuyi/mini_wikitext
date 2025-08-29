defmodule MiniWikitext do
  @moduledoc """
  MiniWikitext - 一个轻量级的 Wikitext 解析器

  提供词法分析和语法解析功能，用于处理 MediaWiki 格式的文本。
  """

  alias MiniWikitext.Parser
  alias MiniWikitext.Renderer

  @doc """
  解析 wikitext 字符串并返回 AST。

  这是 MiniWikitext.Parser.parse/1 的便捷入口。

  ## 参数

    * `wikitext` - 要解析的 wikitext 字符串

  ## 返回值

    返回解析后的 AST 结构。

  ## 示例

      iex> MiniWikitext.parse("== 标题 ==")
      {:ok, %{type: :document, content: []}}

  """
  @spec parse(String.t()) :: any()
  defdelegate parse(wikitext), to: Parser

  @doc """
  渲染 wikitext 为 HTML。

  接收 wikitext 字符串，先解析为 AST，然后渲染为 HTML。

  ## 参数

    * `wikitext` - 要渲染的 wikitext 字符串
    * `opts` - 可选参数
      * `:pretty` - 当设置为 true 时，使用 Floki 对输出的 HTML 进行格式化（默认: false）

  ## 返回值

    返回渲染后的 HTML 字符串。

  ## 示例

      iex> MiniWikitext.render("== 标题 ==")
      "<h2>标题</h2>"

      iex> MiniWikitext.render("== 标题 ==", pretty: true)
      "<h2>标题</h2>"

  """
  @spec render(String.t(), keyword()) :: String.t()
  def render(wikitext, opts \\ []) when is_binary(wikitext) and is_list(opts) do
    html = wikitext
           |> parse()
           |> Renderer.render()
    
    if Keyword.get(opts, :pretty, false) do
      prettify_html(html)
    else
      html
    end
  end

  @doc """
  渲染 AST 为 HTML。

  这是 MiniWikitext.Renderer.render/1 的便捷入口，用于直接渲染已解析的 AST。

  ## 参数

    * `ast` - 由 MiniWikitext.Parser 解析生成的 AST

  ## 返回值

    返回渲染后的 HTML 字符串。

  ## 示例

      iex> ast = MiniWikitext.parse("== 标题 ==")
      iex> MiniWikitext.render_ast(ast)
      "<h2>标题</h2>"

  """
  @spec render_ast(any()) :: String.t()
  defdelegate render_ast(ast), to: Renderer, as: :render

  # 使用 Floki 对 HTML 进行格式化
  defp prettify_html(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        Floki.raw_html(document, pretty: true, encode: false)
      {:error, _reason} ->
        # 如果解析失败，返回原始 HTML
        html
    end
  end
end
