defmodule MiniWikitext.Renderer.RenderTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.{Renderer, VNode}

  describe "集成测试 - 完整段落渲染" do
    test "渲染包含多种元素的段落" do
      # 模拟解析器可能生成的复杂段落结构
      paragraph = VNode.root([
        VNode.element("p", %{}, [
          VNode.text("这是一个包含 "),
          VNode.element("b", %{}, [VNode.text("粗体")]),
          VNode.text("、"),
          VNode.element("i", %{}, [VNode.text("斜体")]),
          VNode.text("、"),
          VNode.element("wikilink", %{href: "示例页面"}, [VNode.text("链接")]),
          VNode.text(" 和 "),
          VNode.element("span", %{class: "highlight"}, [VNode.text("高亮文本")]),
          VNode.text(" 的复杂段落。还有一些特殊字符：& < > \" '")
        ])
      ])
      
      result = Renderer.render(paragraph)
      
      expected = "<p>" <>
                 "这是一个包含 " <>
                 "<b>粗体</b>" <>
                 "、" <>
                 "<i>斜体</i>" <>
                 "、" <>
                 "<wikilink title=\"示例页面\">链接</wikilink>" <>
                 " 和 " <>
                 "<span class=\"highlight\">高亮文本</span>" <>
                 " 的复杂段落。还有一些特殊字符：&amp; &lt; &gt; &quot; &#39;" <>
                 "</p>"
      
      assert result == expected
    end
  end

  describe "基础渲染测试" do
    test "渲染简单的 HTML 结构" do
      ast = VNode.root([
        VNode.element("div", %{class: "container"}, [
          VNode.element("p", %{}, [VNode.text("段落内容")]),
          VNode.element("ul", %{}, [
            VNode.element("li", %{}, [VNode.text("列表项1")]),
            VNode.element("li", %{}, [VNode.text("列表项2")])
          ])
        ])
      ])
      
      result = Renderer.render(ast)
      expected = "<div class=\"container\"><p>段落内容</p><ul><li>列表项1</li><li>列表项2</li></ul></div>"
      
      assert result == expected
    end

    test "渲染行内元素" do
      ast = VNode.root([
        VNode.element("p", %{}, [
          VNode.text("这是一个包含 "),
          VNode.element("b", %{}, [VNode.text("粗体")]),
          VNode.text(" 和 "),
          VNode.element("i", %{}, [VNode.text("斜体")]),
          VNode.text(" 的段落。")
        ])
      ])
      
      result = Renderer.render(ast)
      expected = "<p>这是一个包含 <b>粗体</b> 和 <i>斜体</i> 的段落。</p>"
      
      assert result == expected
    end

    test "渲染自闭合标签" do
      ast = VNode.root([
        VNode.element("div", %{}, [
          VNode.element("p", %{}, [VNode.text("段落1")]),
          VNode.element("hr", %{}, []),
          VNode.element("p", %{}, [VNode.text("段落2")])
        ])
      ])
      
      result = Renderer.render(ast)
      expected = "<div><p>段落1</p><hr /><p>段落2</p></div>"
      
      assert result == expected
    end

    test "通过主模块调用 render_ast 渲染" do
      ast = VNode.root([
        VNode.element("div", %{}, [
          VNode.element("p", %{}, [VNode.text("测试内容")])
        ])
      ])
      
      result = MiniWikitext.render_ast(ast)
      expected = "<div><p>测试内容</p></div>"
      
      assert result == expected
    end
  end
end
