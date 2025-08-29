defmodule MiniWikitext.VNode do
  @moduledoc """
  VNode: Wikitext 抽象语法树节点
  """

  defstruct type: nil,    # :root | :element | :text | :comment
            tag: nil,     # :element 节点才有，比如 "p"、"h1"
            attrs: %{},   # :element 节点的属性
            children: [], # :root 和 :element 的子节点列表
            value: nil,   # :text 节点的内容
            raw: nil      # :comment 节点的原文

  @type t :: %__MODULE__{
          type: :root | :element | :text | :comment,
          tag: String.t() | nil,
          attrs: map(),
          children: [t],
          value: String.t() | nil,
          raw: String.t() | nil
        }

  # 工厂方法，避免手写 map 出错
  def root(children \\ []), do: %__MODULE__{type: :root, children: children}
  def element(tag, attrs \\ %{}, children \\ []),
    do: %__MODULE__{type: :element, tag: tag, attrs: attrs, children: children}
  def text(value), do: %__MODULE__{type: :text, value: value}
  def comment(raw), do: %__MODULE__{type: :comment, raw: raw}
end
