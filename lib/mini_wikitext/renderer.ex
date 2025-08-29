defmodule MiniWikitext.Renderer do
  @moduledoc """
  MiniWikitext.Renderer - Wikitext AST 渲染器

  负责将解析后的 AST 渲染为目标格式（如 HTML）。
  """

  @doc """
  渲染 AST 为 HTML。

  接收一个由 Parser 生成的 AST，并将其转换为 HTML 字符串。

  ## 参数

    * `ast` - 由 MiniWikitext.Parser 解析生成的 AST

  ## 返回值

    返回渲染后的 HTML 字符串。

  ## 示例

      iex> ast = %{type: :document, content: []}
      iex> MiniWikitext.Renderer.render(ast)
      ""

  """
  alias MiniWikitext.VNode

  @spec render(VNode.t()) :: String.t()
  def render(%VNode{} = ast) do
    render_node(ast)
  end

  # 处理根节点
  defp render_node(%VNode{type: :root, children: children}) do
    children
    |> Enum.map(&render_node/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("")
  end

  # 处理文本节点
  defp render_node(%VNode{type: :text, value: value}) when is_binary(value) do
    escape_html(value)
  end

  # 处理注释节点
  defp render_node(%VNode{type: :comment, raw: raw}) when is_binary(raw) do
    raw
  end

  # 处理元素节点
  defp render_node(%VNode{type: :element, tag: tag, attrs: attrs, children: children}) do
    render_element(tag, attrs, children)
  end

  # 兜底处理
  defp render_node(_), do: ""

  # HTML 转义函数
  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  # 渲染元素节点
  defp render_element(tag, attrs, children) do
    case tag do
      "wikilink" -> render_wikilink(attrs, children)
      "table_caption" -> render_table_caption(attrs, children)
      _ -> render_standard_element(tag, attrs, children)
    end
  end

  # 渲染维基链接为 <wikilink> 标签
  defp render_wikilink(attrs, children) do
    href = Map.get(attrs, :href, "")
    title = Map.get(attrs, :title, href)
    
    # 如果没有子节点，使用 href 作为显示文本
    content = if Enum.empty?(children) do
      escape_html(href)
    else
      children |> Enum.map(&render_node/1) |> Enum.join("")
    end

    attrs_str = render_attributes(%{title: title})
    "<wikilink#{attrs_str}>#{content}</wikilink>"
  end

  # 渲染表格标题为 <caption> 标签
  defp render_table_caption(attrs, children) do
    attrs_str = render_attributes(attrs)
    content = render_children_content(children)
    "<caption#{attrs_str}>#{content}</caption>"
  end

  # 渲染标准 HTML 元素
  defp render_standard_element(tag, attrs, children) do
    if self_closing_tag?(tag) do
      attrs_str = render_attributes(attrs)
      "<#{tag}#{attrs_str} />"
    else
      attrs_str = render_attributes(attrs)
      content = render_children_content(children)
      "<#{tag}#{attrs_str}>#{content}</#{tag}>"
    end
  end

  # 判断是否为自闭合标签
  defp self_closing_tag?(tag) do
    tag in ~w(br hr img input area base col embed link meta param source track wbr)
  end

  # 渲染属性
  defp render_attributes(attrs) when is_map(attrs) and map_size(attrs) == 0, do: ""
  defp render_attributes(attrs) when is_map(attrs) do
    attrs
    |> Enum.filter(fn {_key, value} -> value != nil and value != "" end)
    |> Enum.map(fn {key, value} -> 
      key_str = to_string(key)
      value_str = escape_html(to_string(value))
      "#{key_str}=\"#{value_str}\""
    end)
    |> case do
      [] -> ""
      attr_list -> " " <> Enum.join(attr_list, " ")
    end
  end

  # 渲染子节点内容
  defp render_children_content(children) do
    children
    |> Enum.map(&render_node/1)
    |> Enum.join("")
  end
end
