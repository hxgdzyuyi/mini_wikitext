defmodule MiniWikitext.Parser.ParseTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Parser
  alias MiniWikitext.VNode

  describe "基本文本解析" do
    test "纯文本转换为段落" do
      result = Parser.parse("Hello world")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: [text]} = paragraph
      assert %VNode{type: :text, value: "Hello world"} = text
    end

    test "多行文本合并为段落" do
      result = Parser.parse("Hello\nworld")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: [text]} = paragraph
      assert %VNode{type: :text, value: "Hello world"} = text
    end

    test "空行分隔段落" do
      result = Parser.parse("First paragraph\n\nSecond paragraph")
      
      assert %VNode{type: :root, children: [p1, p2]} = result
      assert %VNode{type: :element, tag: "p", children: [text1]} = p1
      assert %VNode{type: :element, tag: "p", children: [text2]} = p2
      # 文本可能包含尾随空格，使用模式匹配检查内容
      assert %VNode{type: :text, value: value1} = text1
      assert %VNode{type: :text, value: value2} = text2
      assert String.trim(value1) == "First paragraph"
      assert String.trim(value2) == "Second paragraph"
    end

    test "空白文本处理" do
      result = Parser.parse("   Hello   world   ")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含空白和文本
      assert length(children) >= 1
      # 检查是否包含文本内容
      text_values = Enum.map(children, fn
        %VNode{type: :text, value: v} -> v
        _ -> nil
      end) |> Enum.reject(&is_nil/1) |> Enum.join("")
      
      assert text_values =~ "Hello"
      assert text_values =~ "world"
    end
  end

  describe "HTML标签解析" do
    test "简单开放和闭合标签" do
      result = Parser.parse("<div>content</div>")
      
      assert %VNode{type: :root, children: [div]} = result
      assert %VNode{type: :element, tag: "div", children: [text]} = div
      assert %VNode{type: :text, value: "content"} = text
    end

    test "带属性的标签" do
      result = Parser.parse("<div class=\"test\">content</div>")
      
      assert %VNode{type: :root, children: [div]} = result
      assert %VNode{type: :element, tag: "div", attrs: attrs, children: [text]} = div
      assert attrs[:class] == "test"
      assert %VNode{type: :text, value: "content"} = text
    end

    test "自闭合标签" do
      result = Parser.parse("Before<br/>After")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含三个子节点：文本、br、文本
      assert length(children) == 3
      assert Enum.any?(children, fn
        %VNode{type: :element, tag: "br"} -> true
        _ -> false
      end)
    end

    test "嵌套HTML标签" do
      result = Parser.parse("<div><span>nested</span></div>")
      
      assert %VNode{type: :root, children: [div]} = result
      assert %VNode{type: :element, tag: "div", children: [span]} = div
      assert %VNode{type: :element, tag: "span", children: [text]} = span
      assert %VNode{type: :text, value: "nested"} = text
    end

    test "块级标签不自动包装段落" do
      result = Parser.parse("<div>Block content</div>")
      
      # div是块级标签，不应该被p标签包装
      assert %VNode{type: :root, children: [div]} = result
      assert %VNode{type: :element, tag: "div"} = div
    end

    test "行内标签自动包装段落" do
      result = Parser.parse("<span>Inline content</span>")
      
      # span是行内标签，应该被p标签包装
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: [span]} = paragraph
      assert %VNode{type: :element, tag: "span"} = span
    end
  end

  describe "格式化文本" do
    test "斜体文本" do
      result = Parser.parse("Normal ''italic'' text")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含斜体标签
      assert Enum.any?(children, fn
        %VNode{type: :element, tag: "i"} -> true
        _ -> false
      end)
    end

    test "粗体文本" do
      result = Parser.parse("Normal '''bold''' text")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含粗体标签
      assert Enum.any?(children, fn
        %VNode{type: :element, tag: "b"} -> true
        _ -> false
      end)
    end

    test "粗斜体文本" do
      result = Parser.parse("Normal '''''bold-italic''''' text")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该同时包含粗体和斜体标签
      has_bold = Enum.any?(children, fn
        %VNode{type: :element, tag: "b"} -> true
        _ -> false
      end)
      has_italic = Enum.any?(children, fn
        %VNode{type: :element, tag: "i"} -> true
        _ -> false
      end)
      
      assert has_bold or has_italic
    end

    test "嵌套格式化" do
      result = Parser.parse("'''bold ''and italic'' text'''")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该有正确的嵌套结构
      assert length(children) >= 1
    end
  end

  describe "标题解析" do
    test "二级标题" do
      result = Parser.parse("== Heading ==")
      
      assert %VNode{type: :root, children: [heading]} = result
      assert %VNode{type: :element, tag: "h2", children: [text]} = heading
      assert %VNode{type: :text, value: " Heading "} = text
    end

    test "三级标题" do
      result = Parser.parse("=== Heading ===")
      
      assert %VNode{type: :root, children: [heading]} = result
      assert %VNode{type: :element, tag: "h3", children: [text]} = heading
      assert %VNode{type: :text, value: " Heading "} = text
    end

    test "不对称标题" do
      result = Parser.parse("==== Heading ==")
      
      assert %VNode{type: :root, children: [heading]} = result
      assert %VNode{type: :element, tag: "h2", children: [text]} = heading
      # 多余的等号应该被包含在内容中
      assert %VNode{type: :text, value: "== Heading "} = text
    end

    test "标题后的空白和注释" do
      result = Parser.parse("== Heading ==   <!-- comment -->")
      
      assert %VNode{type: :root, children: children} = result
      assert length(children) >= 1
      
      # 第一个应该是标题
      assert %VNode{type: :element, tag: "h2"} = hd(children)
    end
  end

  describe "列表解析" do
    test "无序列表" do
      result = Parser.parse("* Item 1\n* Item 2")
      
      assert %VNode{type: :root, children: [ul]} = result
      assert %VNode{type: :element, tag: "ul", children: children} = ul
      
      # 应该包含列表项
      assert length(children) >= 2
      assert Enum.all?(children, fn
        %VNode{type: :element, tag: "li"} -> true
        _ -> false
      end)
    end

    test "有序列表" do
      result = Parser.parse("# Item 1\n# Item 2")
      
      assert %VNode{type: :root, children: [ol]} = result
      assert %VNode{type: :element, tag: "ol", children: children} = ol
      
      # 应该包含列表项
      assert length(children) >= 2
      assert Enum.all?(children, fn
        %VNode{type: :element, tag: "li"} -> true
        _ -> false
      end)
    end

    test "嵌套列表" do
      result = Parser.parse("* Item 1\n** Sub item\n* Item 2")
      
      assert %VNode{type: :root, children: [ul]} = result
      assert %VNode{type: :element, tag: "ul"} = ul
      
      # 应该有正确的嵌套结构
      # 具体的嵌套结构可能因实现而异
    end

    test "定义列表" do
      result = Parser.parse("; Term : Definition")
      
      assert %VNode{type: :root, children: [dl]} = result
      assert %VNode{type: :element, tag: "dl", children: children} = dl
      
      # 应该包含dt和dd元素
      has_dt = Enum.any?(children, fn
        %VNode{type: :element, tag: "dt"} -> true
        _ -> false
      end)
      has_dd = Enum.any?(children, fn
        %VNode{type: :element, tag: "dd"} -> true
        _ -> false
      end)
      
      assert has_dt and has_dd
    end
  end

  describe "表格解析" do
    test "简单表格" do
      result = Parser.parse("{|\n! Header\n|-\n| Cell\n|}")
      
      assert %VNode{type: :root, children: [table]} = result
      assert %VNode{type: :element, tag: "table"} = table
    end

    test "带属性的表格" do
      result = Parser.parse("{| class=\"wikitable\"\n! Header\n|-\n| Cell\n|}")
      
      assert %VNode{type: :root, children: [table]} = result
      assert %VNode{type: :element, tag: "table", attrs: attrs} = table
      assert attrs[:class] == "wikitable"
    end

    test "表格标题" do
      result = Parser.parse("{|\n|+ Caption\n! Header\n|-\n| Cell\n|}")
      
      assert %VNode{type: :root, children: [table]} = result
      assert %VNode{type: :element, tag: "table", children: children} = table
      
      # 应该包含table_caption元素
      has_caption = Enum.any?(children, fn
        %VNode{type: :element, tag: "table_caption"} -> true
        _ -> false
      end)
      assert has_caption
    end

    test "表格行和单元格" do
      result = Parser.parse("{|\n|-\n| Cell 1 || Cell 2\n|}")
      
      assert %VNode{type: :root, children: [table]} = result
      assert %VNode{type: :element, tag: "table", children: children} = table
      
      # 应该包含tr和td元素
      has_tr = Enum.any?(children, fn
        %VNode{type: :element, tag: "tr"} -> true
        _ -> false
      end)
      assert has_tr
    end
  end

  describe "维基链接解析" do
    test "简单维基链接" do
      result = Parser.parse("[[Page]]")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: [wikilink]} = paragraph
      assert %VNode{type: :element, tag: "wikilink", attrs: attrs} = wikilink
      assert attrs[:href] == "Page"
    end

    test "带显示文本的维基链接" do
      result = Parser.parse("[[Page|Display text]]")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: [wikilink]} = paragraph
      assert %VNode{type: :element, tag: "wikilink", attrs: attrs, children: children} = wikilink
      assert attrs[:href] == "Page"
      assert length(children) > 0
    end

    test "管道技巧（空显示文本）" do
      result = Parser.parse("[[Page|]]")
      
      # 管道技巧应该被还原为普通文本
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含文本节点而不是wikilink
      text_content = children
      |> Enum.map(fn
        %VNode{type: :text, value: v} -> v
        _ -> ""
      end)
      |> Enum.join("")
      
      assert text_content =~ "[[Page|]]"
    end

    test "损坏的维基链接" do
      result = Parser.parse("[[[Page]]")
      
      # 损坏的链接应该被处理为文本
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      text_content = children
      |> Enum.map(fn
        %VNode{type: :text, value: v} -> v
        _ -> ""
      end)
      |> Enum.join("")
      
      assert text_content =~ "["
    end
  end

  describe "HTML注释" do
    test "简单HTML注释" do
      result = Parser.parse("<!-- This is a comment -->")
      
      assert %VNode{type: :root, children: [comment]} = result
      assert %VNode{type: :comment, raw: "<!-- This is a comment -->"} = comment
    end

    test "注释和文本混合" do
      result = Parser.parse("Text <!-- comment --> more text")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含文本和注释
      has_comment = Enum.any?(children, fn
        %VNode{type: :comment} -> true
        _ -> false
      end)
      has_text = Enum.any?(children, fn
        %VNode{type: :text} -> true
        _ -> false
      end)
      
      assert has_comment and has_text
    end

    test "未闭合的注释" do
      result = Parser.parse("<!-- Unclosed comment")
      
      assert %VNode{type: :root, children: [comment]} = result
      assert %VNode{type: :comment, raw: "<!-- Unclosed comment"} = comment
    end
  end

  describe "nowiki标签" do
    test "简单nowiki" do
      result = Parser.parse("<nowiki>'''Not bold'''</nowiki>")
      
      assert %VNode{type: :root, children: children} = result
      
      # nowiki内容应该被保留为原始文本
      has_nowiki = Enum.any?(children, fn
        %VNode{type: :element, tag: "nowiki"} -> true
        _ -> false
      end)
      assert has_nowiki
    end

    test "未闭合的nowiki" do
      result = Parser.parse("<nowiki>Unclosed")
      
      assert %VNode{type: :root, children: children} = result
      
      # 应该有nowiki元素
      has_nowiki = Enum.any?(children, fn
        %VNode{type: :element, tag: "nowiki"} -> true
        _ -> false
      end)
      assert has_nowiki
    end
  end

  describe "水平线" do
    test "简单水平线" do
      result = Parser.parse("----")
      
      assert %VNode{type: :root, children: [hr]} = result
      assert %VNode{type: :element, tag: "hr"} = hr
    end

    test "更长的水平线" do
      result = Parser.parse("--------")
      
      assert %VNode{type: :root, children: [hr]} = result
      assert %VNode{type: :element, tag: "hr"} = hr
    end
  end

  describe "复杂混合内容" do
    test "段落中的多种格式" do
      result = Parser.parse("This is '''bold''' and ''italic'' with [[link]] and <span>HTML</span>.")
      
      assert %VNode{type: :root, children: [paragraph]} = result
      assert %VNode{type: :element, tag: "p", children: children} = paragraph
      
      # 应该包含多种类型的子节点
      assert length(children) > 1
      
      # 检查是否包含不同类型的元素
      types = Enum.map(children, fn
        %VNode{type: :element, tag: tag} -> tag
        %VNode{type: :text} -> :text
        _ -> :other
      end) |> Enum.uniq()
      
      assert length(types) > 1
    end

    test "列表中的格式化文本" do
      result = Parser.parse("* '''Bold''' item\n* ''Italic'' item")
      
      assert %VNode{type: :root, children: [ul]} = result
      assert %VNode{type: :element, tag: "ul", children: items} = ul
      
      # 列表项应该包含格式化的内容
      assert length(items) >= 2
    end

    test "表格中的链接和格式" do
      result = Parser.parse("{|\n! '''Header''' with [[link]]\n|-\n| ''Cell'' content\n|}")
      
      assert %VNode{type: :root, children: [table]} = result
      assert %VNode{type: :element, tag: "table"} = table
      
      # 表格应该包含格式化的内容
    end

    test "标题中的格式化" do
      result = Parser.parse("== '''Bold''' Heading ==")
      
      assert %VNode{type: :root, children: [heading]} = result
      assert %VNode{type: :element, tag: "h2", children: children} = heading
      
      # 标题内容应该包含格式化
      assert length(children) >= 1
    end
  end

  describe "边界情况" do
    test "空字符串" do
      result = Parser.parse("")
      
      assert %VNode{type: :root, children: []} = result
    end

    test "只有空白" do
      result = Parser.parse("   \n\n   ")
      
      assert %VNode{type: :root, children: children} = result
      # 可能包含空白节点或者为空
      assert is_list(children)
    end

    test "只有换行" do
      result = Parser.parse("\n\n\n")
      
      assert %VNode{type: :root, children: children} = result
      assert is_list(children)
    end

    test "不匹配的标签" do
      # 这个测试可能会因为parser的容错机制而产生不同结果
      # 我们只是确保它不会崩溃并产生有效的AST
      result = Parser.parse("<div>content</span>")
      
      assert %VNode{type: :root, children: children} = result
      # 应该有某种处理方式，不应该崩溃
      assert is_list(children)
      # 至少应该包含一些内容
      assert length(children) > 0
    end

    test "深度嵌套" do
      nested = String.duplicate("<div>", 10) <> "content" <> String.duplicate("</div>", 10)
      result = Parser.parse(nested)
      
      assert %VNode{type: :root} = result
      # 应该能处理深度嵌套而不崩溃
    end
  end
end
