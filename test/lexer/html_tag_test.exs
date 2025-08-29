defmodule MiniWikitext.Lexer.HtmlTagTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "HTML 标签测试" do
    test "<tag ...> 开始标签 </tag> 结束标签" do
      # 测试基本的开始标签
      lexer = Lexer.new("<div>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.raw == "<div>"
      assert token.tag == "div"
      assert token.options == %{}

      # 测试带属性的开始标签
      lexer = Lexer.new("<div class=\"content\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.raw == "<div class=\"content\">"
      assert token.tag == "div"
      assert token.options == %{class: "content"}

      # 测试结束标签
      lexer = Lexer.new("</div>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :close
      assert token.raw == "</div>"
      assert token.tag == "div"
      assert token.options == %{}
    end

    test "特别处理 </br> 视为 <br/>" do
      # 测试 </br> 被特殊处理为自闭合标签
      lexer = Lexer.new("</br>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :self_closing
      assert token.raw == "</br>"
      assert token.tag == "br"
      assert token.options == %{}
    end

    test "<tag ... /> 自闭合标签，及 / > 的形式" do
      # 测试标准自闭合标签
      lexer = Lexer.new("<img src=\"test.jpg\"/>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :self_closing
      assert token.raw == "<img src=\"test.jpg\"/>"
      assert token.tag == "img"
      assert token.options == %{src: "test.jpg"}

      # 测试 / > 形式（空格分隔）
      lexer = Lexer.new("<img src=\"test.jpg\" />")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :self_closing
      assert token.raw == "<img src=\"test.jpg\" />"
      assert token.tag == "img"
      assert token.options == %{src: "test.jpg"}

      # 测试多个空格的 / > 形式
      lexer = Lexer.new("<br   />")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :self_closing
      assert token.raw == "<br   />"
      assert token.tag == "br"
      assert token.options == %{}
    end

    test "属性名：[^\\s=\\/>]+" do
      # 测试各种合法的属性名
      lexer = Lexer.new("<div data-test=\"value\" class123=\"test\" _hidden=\"true\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.tag == "div"
      assert token.options[:"data-test"] == "value"
      assert token.options[:class123] == "test"
      assert token.options[:_hidden] == "true"

      # 测试包含冒号的属性名（如 XML 命名空间）
      lexer = Lexer.new("<root xmlns:xsi=\"http://example.com\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.tag == "root"
      assert token.options[:"xmlns:xsi"] == "http://example.com"
    end

    test "属性值：\"双引号\" / '单引号' / 未加引号" do
      # 测试双引号属性值
      lexer = Lexer.new("<div class=\"my-class\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.options[:class] == "my-class"

      # 测试单引号属性值
      lexer = Lexer.new("<div class='my-class'>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.options[:class] == "my-class"

      # 测试未加引号的属性值
      lexer = Lexer.new("<div class=my-class>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.options[:class] == "my-class"

      # 测试没有值的属性（布尔属性）
      lexer = Lexer.new("<input disabled>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.options[:disabled] == true

      # 测试空字符串属性值
      lexer = Lexer.new("<input value=\"\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.options[:value] == ""

      # 测试混合的属性值类型
      lexer = Lexer.new("<input type=text value=\"hello world\" disabled checked='true'>")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.options[:type] == "text"
      assert token.options[:value] == "hello world"
      assert token.options[:disabled] == true
      assert token.options[:checked] == "true"
    end

    test "属性与结尾处可含换行；在 > 前允许出现若干\"无意义的 /\"" do
      # 测试属性中包含换行
      input =
        """
        <div
          class="test"
          id="my-id"
          data-value="hello">
        """
        |> String.trim()

      lexer = Lexer.new(input)
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.tag == "div"
      assert token.options[:class] == "test"
      assert token.options[:id] == "my-id"
      assert token.options[:"data-value"] == "hello"

      # 测试在 > 前的无意义的 /
      lexer = Lexer.new("<div class=\"test\" / / />")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :self_closing
      assert token.tag == "div"
      assert token.options[:class] == "test"

      # 测试在普通标签中的无意义的 /
      lexer = Lexer.new("<div class=\"test\" / / >")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.tag == "div"
      assert token.options[:class] == "test"

      # 测试换行和无意义的 / 混合
      input =
        """
        <div
          class="test"
          /
          /
          />
        """
        |> String.trim()

      lexer = Lexer.new(input)
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :self_closing
      assert token.tag == "div"
      assert token.options[:class] == "test"
    end

    test "复杂的 HTML 标签场景" do
      # 测试大小写混合的标签名（应该转换为小写）
      lexer = Lexer.new("<DIV Class=\"Test\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      # 标签名转为小写
      assert token.tag == "div"
      # 属性名保持原样
      assert token.options[:Class] == "Test"

      # 测试包含数字的标签名
      lexer = Lexer.new("<h1 id=\"title\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.tag == "h1"
      assert token.options[:id] == "title"

      # 测试自定义标签名
      lexer = Lexer.new("<my-custom-tag data=\"value\">")
      {token, _lexer} = Lexer.next(lexer)

      assert token.type == :open
      assert token.tag == "my-custom-tag"
      assert token.options[:data] == "value"
    end

    test "使用 Lexer.next 遍历完整的标签序列" do
      # 测试完整的开始标签 + 内容 + 结束标签序列
      input = "<div class=\"container\">Hello World</div>"
      lexer = Lexer.new(input)

      # 第一个 token：开始标签
      {token1, lexer} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.tag == "div"
      assert token1.options[:class] == "container"

      # 第二个 token：文本内容
      {token2, lexer} = Lexer.next(lexer)
      assert token2.type == :text
      assert token2.raw == "Hello World"

      # 第三个 token：结束标签
      {token3, _lexer} = Lexer.next(lexer)
      assert token3.type == :close
      assert token3.tag == "div"
    end

    test "嵌套标签的遍历" do
      # 测试嵌套标签的完整遍历
      input = "<div><span class=\"highlight\">Text</span></div>"
      lexer = Lexer.new(input)

      tokens = []
      {token, lexer} = Lexer.next(lexer)
      tokens = [token | tokens]

      {token, lexer} = Lexer.next(lexer)
      tokens = [token | tokens]

      {token, lexer} = Lexer.next(lexer)
      tokens = [token | tokens]

      {token, lexer} = Lexer.next(lexer)
      tokens = [token | tokens]

      {token, _lexer} = Lexer.next(lexer)
      tokens = [token | tokens]

      tokens = Enum.reverse(tokens)

      # 验证 token 序列
      assert Enum.at(tokens, 0).type == :open
      assert Enum.at(tokens, 0).tag == "div"

      assert Enum.at(tokens, 1).type == :open
      assert Enum.at(tokens, 1).tag == "span"
      assert Enum.at(tokens, 1).options[:class] == "highlight"

      assert Enum.at(tokens, 2).type == :text
      assert Enum.at(tokens, 2).raw == "Text"

      assert Enum.at(tokens, 3).type == :close
      assert Enum.at(tokens, 3).tag == "span"

      assert Enum.at(tokens, 4).type == :close
      assert Enum.at(tokens, 4).tag == "div"
    end
  end
end
