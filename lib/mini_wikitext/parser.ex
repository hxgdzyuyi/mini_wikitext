defmodule MiniWikitext.Parser do
  @moduledoc """
  Wikitext Parser -> tokens => VNode AST

  返回：
    %MiniWikitext.VNode{type: :root, children: [...]}
  规则：
    * :text / :space / 行内标签 => 进入段落（必要时自动打开 <p>）
    * 段落内单个换行 => 转为空格；连续两个及以上换行 => 结束段落
    * 相邻文本节点合并
    * 遇到块级 open/self_closing/close => 先结束段落再处理
  """

  alias MiniWikitext.Lexer
  alias MiniWikitext.VNode

  @type ast :: VNode.t()

  @inline_tags MapSet.new(~w(i b em strong span a code tt kbd samp small big sup sub br img wikilink))
  @block_tags  MapSet.new(~w(div p pre blockquote ul ol dl li dt dd table thead tbody tfoot tr td th table_caption hr nowiki))
  @heading_tags MapSet.new(Enum.map(1..6, &"h#{&1}"))

  @spec parse(String.t()) :: ast
  def parse(wikitext) when is_binary(wikitext) do
    lx = Lexer.new(wikitext)
    stack = [new_root_frame()]
    newline_run = 0
    loop(lx, stack, newline_run)
  end

  # ================= Main loop =================

  # 读取 token 并构建 AST；返回最终 Root VNode
  defp loop(lx, stack, newline_run) do
    {tok, lx1} = Lexer.next(lx)

    case tok.type do
      :eof ->
        stack
        |> close_paragraph_if_open()
        |> close_all_frames_to_root()
        |> root_from_stack()

      :newline ->
        if in_paragraph?(stack) do
          # 段内：一个换行=空格；两个换行=结束段落
          if newline_run + 1 >= 2 do
            loop(lx1, pop_until(stack, "p"), 0)
          else
            stack
            |> append_text(" ")
            |> then(&loop(lx1, &1, newline_run + 1))
          end
        else
          loop(lx1, stack, newline_run + 1)
        end

      :space ->
        stack
        |> ensure_paragraph()
        |> append_text(tok.raw)
        |> then(&loop(lx1, &1, 0))

      :text ->
        stack
        |> ensure_paragraph()
        |> append_text(tok.raw)
        |> then(&loop(lx1, &1, 0))

      :html_comment ->
        # 注释不强制段落边界，按当前位置直接插入
        stack
        |> append_node(VNode.comment(tok.raw))
        |> then(&loop(lx1, &1, 0))

      :self_closing ->
        tag = tok.tag || ""
        attrs = tok.options || %{}
        node = self_closing_to_node(tag, attrs)

        stack =
          if is_block_tag?(tag) do
            stack
            |> close_paragraph_if_open()
            |> append_node(node)
          else
            stack
            |> ensure_paragraph()
            |> append_node(node)
          end

        loop(lx1, stack, 0)

      :open ->
        tag = tok.tag || ""
        attrs = tok.options || %{}

        stack =
          if is_block_tag?(tag) do
            stack
            |> close_paragraph_if_open()
            |> push_element(tag, attrs)
          else
            stack
            |> ensure_paragraph()
            |> push_element(tag, attrs)
          end

        loop(lx1, stack, 0)

      :close ->
        tag = tok.tag || ""
        # 容错：若找不到匹配，忽略
        stack =
          if has_tag_in_stack?(stack, tag) do
            pop_until(stack, tag)
          else
            stack
          end

        loop(lx1, stack, 0)

      # 兜底：把原文当文本
      _other ->
        stack
        |> ensure_paragraph()
        |> append_text(to_string(tok.raw || ""))
        |> then(&loop(lx1, &1, 0))
    end
  end

  # ================= Frame stack (不可变构建) =================

  # Frame 结构：%{kind: :root | :element, tag: String.t() | nil, attrs: map(), children: [VNode] (逆序累加)}
  defp new_root_frame, do: %{kind: :root, children: []}
  defp new_element_frame(tag, attrs), do: %{kind: :element, tag: tag, attrs: attrs, children: []}

  defp push_element(stack, tag, attrs), do: [new_element_frame(tag, attrs) | stack]

  # 关闭一个 frame，并把生成的 VNode 作为子节点加入父 frame
  defp close_one_frame([top, parent | rest]) do
    node = frame_to_node(top)
    parent = append_node_to_frame(parent, node)
    [parent | rest]
  end

  defp close_one_frame([root]), do: [root] # 根不再上浮

  # 弹出直到并包含 tag（会依次完成各自子树）
  defp pop_until([%{kind: :element, tag: tag} | _] = stack, tag), do: close_one_frame(stack)
  defp pop_until([_ | _] = stack, tag), do: pop_until(close_one_frame(stack), tag)
  defp pop_until([], _), do: []

  # 收束到 root（但 root 仍为 frame）
  defp close_all_frames_to_root([%{kind: :root} | _] = stack), do: stack
  defp close_all_frames_to_root(stack), do: stack |> close_one_frame() |> close_all_frames_to_root()

  # 从最终的 root frame 取出 Root VNode
  defp root_from_stack([%{kind: :root, children: rev_children}]), do: VNode.root(Enum.reverse(rev_children))

  # ======== 添加子节点 / 文本合并 ========

  defp append_node([top | rest], %VNode{} = node) do
    [append_node_to_frame(top, node) | rest]
  end

  defp append_node_to_frame(%{children: children} = frame, %VNode{type: :text, value: v}) do
    case children do
      [%VNode{type: :text, value: prev} = t | tail] ->
        merged = %VNode{t | value: prev <> v}
        %{frame | children: [merged | tail]}

      _ ->
        %{frame | children: [VNode.text(v) | children]}
    end
  end

  defp append_node_to_frame(%{children: children} = frame, %VNode{} = node) do
    %{frame | children: [node | children]}
  end

  defp append_text(stack, txt), do: append_node(stack, VNode.text(txt))

  # ======== 段落控制 ========

  defp ensure_paragraph(stack) do
    if in_paragraph?(stack) do
      stack
    else
      case stack do
        [%{kind: :root} | _] ->
          [new_element_frame("p", %{}) | stack]

        _ ->
          # 其他容器（如 h1..h6、div、pre、table/tr/ul/ol/dl 等）不自动开段落
          stack
      end
    end
  end

  defp close_paragraph_if_open(stack) do
    if in_paragraph?(stack), do: pop_until(stack, "p"), else: stack
  end

  defp in_paragraph?(stack),
    do: Enum.any?(stack, fn
      %{kind: :element, tag: "p"} -> true
      _ -> false
    end)

  defp has_tag_in_stack?(stack, tag),
    do: Enum.any?(stack, fn
      %{kind: :element, tag: t} -> t == tag
      _ -> false
    end)

  # ======== Frame -> VNode ========

  defp frame_to_node(%{kind: :root, children: rev_children}),
    do: VNode.root(Enum.reverse(rev_children))

  defp frame_to_node(%{kind: :element, tag: tag, attrs: attrs, children: rev_children}),
    do: VNode.element(tag, attrs, Enum.reverse(rev_children))

  # ======== token 映射 ========

  defp self_closing_to_node("wikilink", attrs) when is_map(attrs) do
    contents = Map.get(attrs, :contents, [])
    attrs2 = Map.drop(attrs, [:contents])
    children = Enum.map(contents, &VNode.text/1)
    VNode.element("wikilink", attrs2, children)
  end

  defp self_closing_to_node(tag, attrs) do
    VNode.element(tag, attrs || %{}, [])
  end

  # ======== 语义：块/行内判断 ========

  defp is_block_tag?(tag) when is_binary(tag) do
    MapSet.member?(@block_tags, tag) or
      MapSet.member?(@heading_tags, tag) or
      (not MapSet.member?(@inline_tags, tag) and tag not in ["br", "img"])
  end
end
