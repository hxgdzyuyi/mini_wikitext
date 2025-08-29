defmodule MiniWikitext.Lexer.NoWikiTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "nowiki 标签测试" do
    test "基本的闭合 nowiki 标签" do
      # 测试基本的 <nowiki>内容</nowiki> 格式
      lexer = Lexer.new("<nowiki>这是 nowiki 内容</nowiki>")
      {token1, lexer2} = Lexer.next(lexer)

      # 第一个 token 应该是 tag_open
      assert token1.type == :open
      assert token1.raw == "<nowiki>"
      assert token1.tag == "nowiki"
      assert token1.options == %{}
      assert token1.lineno == 1
      assert token1.column == 1

      # 从 stash 中获取下一个 token（内容）
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "这是 nowiki 内容"

      # 从 stash 中获取第三个 token（关闭标签）
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "</nowiki>"
      assert token3.tag == "nowiki"
      assert token3.options == %{}
    end

    test "空的 nowiki 标签" do
      # 测试 <nowiki></nowiki> 空标签
      lexer = Lexer.new("<nowiki></nowiki>")
      {token1, lexer2} = Lexer.next(lexer)

      # 第一个 token 是开始标签
      assert token1.type == :open
      assert token1.raw == "<nowiki>"

      # 第二个 token 是空的文本内容
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == ""

      # 第三个 token 是结束标签
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "</nowiki>"
    end

    test "未闭合的 nowiki 标签" do
      # 测试只有开始标签没有结束标签的情况
      lexer = Lexer.new("<nowiki>这是未闭合的内容")
      {token, lexer2} = Lexer.next(lexer)

      # 应该只返回开始标签
      assert token.type == :open
      assert token.raw == "<nowiki>"
      assert token.tag == "nowiki"
      assert token.options == %{}

      # stash 应该为空，因为没有找到结束标签
      assert lexer2.stash == []

      # 剩余的字符串应该是去掉 <nowiki> 后的部分
      assert lexer2.str == "这是未闭合的内容"
    end

    test "多行 nowiki 内容" do
      # 测试跨多行的 nowiki 内容
      input =
        """
        <nowiki>这是
        多行的
        nowiki 内容</nowiki>
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)
      {token1, lexer2} = Lexer.next(lexer)

      # 第一个 token 是开始标签
      assert token1.type == :open
      assert token1.raw == "<nowiki>"

      # 第二个 token 是多行文本内容
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "这是\n多行的\nnowiki 内容"

      # 第三个 token 是结束标签
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "</nowiki>"
    end

    test "nowiki 中包含特殊字符和标记" do
      # 测试 nowiki 中包含各种特殊字符和 wiki 标记
      content = "'''粗体''' [[链接]] {{模板}} <tag>html</tag> & < >"
      input = "<nowiki>#{content}</nowiki>"

      lexer = Lexer.new(input)
      # 跳过开始标签
      {_token1, lexer2} = Lexer.next(lexer)
      # 获取内容
      {token2, _lexer3} = Lexer.next(lexer2)

      assert token2.type == :text
      assert token2.raw == content
    end

    test "nowiki 中包含 HTML 注释" do
      # 测试 nowiki 中包含 HTML 注释的情况
      content = "<!-- 这是注释 --> 普通文本"
      input = "<nowiki>#{content}</nowiki>"

      lexer = Lexer.new(input)
      # 跳过开始标签
      {_token1, lexer2} = Lexer.next(lexer)
      # 获取内容
      {token2, _lexer3} = Lexer.next(lexer2)

      assert token2.type == :text
      assert token2.raw == content
    end

    test "nowiki 后面还有其他内容" do
      # 测试 nowiki 标签后面还有其他文本的情况
      # 注意：根据 nowiki_rule 的实现，lexer.str 在处理 nowiki 时不会跳过整个块
      lexer = Lexer.new("<nowiki>内容</nowiki>后面的文本")

      # 获取第一个 token（开始标签）
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "<nowiki>"

      # lexer2.str 应该是跳过了 "<nowiki>" 后的内容
      assert lexer2.str == "内容</nowiki>后面的文本"

      # 获取第二个 token（内容）
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "内容"

      # 获取第三个 token（结束标签）
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "</nowiki>"

      # 此时 stash 应该为空，但 lexer4.str 仍然包含原始的内容
      # 因为 nowiki_rule 只跳过了开始标签的长度
      assert lexer4.stash == []
    end

    test "nowiki 标签的位置信息" do
      # 测试 nowiki 标签的行号和列号信息
      lexer = Lexer.new("<nowiki>内容</nowiki>")
      {token, _lexer2} = Lexer.next(lexer)

      assert token.lineno == 1
      assert token.column == 1
    end

    test "嵌套样式的 nowiki 内容" do
      # 测试 nowiki 中包含看起来像嵌套的标签
      # 实际上，nowiki_rule 会在遇到第一个 </nowiki> 时停止
      input = "<nowiki><nowiki>内层</nowiki> 中间文本</nowiki>"

      lexer = Lexer.new(input)
      # 跳过开始标签
      {_token1, lexer2} = Lexer.next(lexer)
      # 获取内容
      {token2, _lexer3} = Lexer.next(lexer2)

      # 内容应该只到第一个 </nowiki>，即 "<nowiki>内层"
      assert token2.type == :text
      assert token2.raw == "<nowiki>内层"
    end
  end

  describe "非 nowiki 情况测试" do
    test "不是以 <nowiki> 开头的内容不应该被识别为 nowiki" do
      # 测试不匹配 nowiki 模式的情况
      lexer = Lexer.new("普通文本")
      {token, _lexer} = Lexer.next(lexer)

      # 应该不是 tag_open 类型，或者如果是 tag_open 也不应该是 nowiki
      refute token.type == :open && token.tag == "nowiki"
    end

    test "不完整的 nowiki 开始标记" do
      # 测试各种不完整的 nowiki 开始标记
      test_cases = [
        "<",
        "<n",
        "<no",
        "<now",
        "<nowi",
        "<nowik",
        "<nowiki",
        "< nowiki>"
      ]

      Enum.each(test_cases, fn input ->
        lexer = Lexer.new(input)
        {token, _lexer} = Lexer.next(lexer)

        # 这些都不应该被识别为 nowiki tag_open
        refute token.type == :open && token.tag == "nowiki",
               "输入 '#{input}' 被错误识别为 nowiki"
      end)
    end

    test "nowiki 标记出现在文本中间" do
      # 测试当 <nowiki> 不在开头时的情况
      lexer = Lexer.new("文本 <nowiki>这不是开头的标签</nowiki>")
      {token, _lexer} = Lexer.next(lexer)

      # 第一个 token 不应该是 nowiki tag_open（因为不是从开头开始）
      refute token.type == :open && token.tag == "nowiki"
    end

    test "类似 nowiki 但不同的标签" do
      # 测试类似但不同的标签名
      test_cases = [
        "<wiki>内容</wiki>",
        "<pre>内容</pre>",
        "<code>内容</code>",
        "<nowrap>内容</nowrap>"
      ]

      Enum.each(test_cases, fn input ->
        lexer = Lexer.new(input)
        {token, _lexer} = Lexer.next(lexer)

        # 这些都不应该被识别为 nowiki
        refute token.type == :open && token.tag == "nowiki",
               "输入 '#{input}' 被错误识别为 nowiki"
      end)
    end
  end

  describe "stash 机制测试" do
    test "nowiki 的 stash 顺序" do
      # 测试 stash 中 token 的顺序是否正确
      lexer = Lexer.new("<nowiki>内容</nowiki>")

      # 第一次调用应该返回开始标签，并将内容和结束标签放入 stash
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "<nowiki>"

      # stash 中应该有两个元素：文本内容和结束标签
      assert length(lexer2.stash) == 2

      # 第二次调用应该从 stash 中取出文本内容
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "内容"

      # stash 中应该剩一个元素：结束标签
      assert length(lexer3.stash) == 1

      # 第三次调用应该从 stash 中取出结束标签
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "</nowiki>"

      # stash 应该为空
      assert length(lexer4.stash) == 0
    end

    test "未闭合 nowiki 的 stash 状态" do
      # 测试未闭合的 nowiki 不会向 stash 中添加内容
      lexer = Lexer.new("<nowiki>未闭合内容")
      {_token, lexer2} = Lexer.next(lexer)

      # stash 应该为空，因为没有找到结束标签
      assert lexer2.stash == []
    end
  end
end
