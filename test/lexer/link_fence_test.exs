defmodule MiniWikitext.Lexer.LinkFenceTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "link_fence_rule 测试" do
    test "基本的 wikilink [[target]]" do
      # 测试最基本的 wikilink 语法
      lexer = Lexer.new("[[HomePage]]")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "[[HomePage]]"
      assert token.tag == "wikilink"
      assert token.options.href == "HomePage"
      assert token.options.contents == []
      assert token.options.firstPipeSrc == nil
      assert token.lineno == 1
      assert token.column == 1
    end

    test "带有内容的 wikilink [[target|display]]" do
      # 测试带有显示文本的 wikilink
      lexer = Lexer.new("[[HomePage|首页]]")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "[[HomePage|首页]]"
      assert token.tag == "wikilink"
      assert token.options.href == "HomePage"
      assert token.options.contents == ["首页"]
      assert token.options.firstPipeSrc == "|"
    end

    test "多个内容段的 wikilink [[target|content1|content2]]" do
      # 测试多个内容段的情况
      lexer = Lexer.new("[[HomePage|首页|主页]]")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "[[HomePage|首页|主页]]"
      assert token.tag == "wikilink"
      assert token.options.href == "HomePage"
      assert token.options.contents == ["首页", "主页"]
      assert token.options.firstPipeSrc == "|"
    end

    test "pipe trick - 空的显示内容 [[target|]]" do
      # 测试 pipe trick：空的显示内容应该还原为文本序列
      lexer = Lexer.new("[[HomePage|]]")

      # 第一个 token: '[[' 文本
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "[["

      # 第二个 token: 'HomePage' 文本
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "HomePage"

      # 第三个 token: '|' 文本
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "|"

      # 第四个 token: ']]' 文本
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :text
      assert token4.raw == "]]"
    end

    test "空的 target [[]]" do
      # 测试空的目标应该还原为文本序列
      lexer = Lexer.new("[[]]")

      # 第一个 token: '[[' 文本
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "[["

      # 第二个 token: ']]' 文本
      {token2, _lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "]]"
    end

    test "broken wikilink - 三个连续的 [ - [[[" do
      # 测试 broken wikilink：三个连续的方括号只消费一个
      lexer = Lexer.new("[[[something]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[[something]]"
      assert lexer2.str == "[[something]]"
    end

    test "broken wikilink - 以 http 开头 [[http://example.com]]" do
      # 测试 broken wikilink：以 http 开头的外链
      lexer = Lexer.new("[[http://example.com]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[http://example.com]]"
      assert lexer2.str == "[http://example.com]]"
    end

    test "broken wikilink - 以 https 开头 [[https://example.com]]" do
      # 测试 broken wikilink：以 https 开头的外链
      lexer = Lexer.new("[[https://example.com]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[https://example.com]]"
      assert lexer2.str == "[https://example.com]]"
    end

    test "broken wikilink - 以 ftp 开头 [[ftp://example.com]]" do
      # 测试 broken wikilink：以 ftp 开头的外链
      lexer = Lexer.new("[[ftp://example.com]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[ftp://example.com]]"
      assert lexer2.str == "[ftp://example.com]]"
    end

    test "broken wikilink - 以 mailto 开头 [[mailto:test@example.com]]" do
      # 测试 broken wikilink：以 mailto 开头的外链
      lexer = Lexer.new("[[mailto:test@example.com]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[mailto:test@example.com]]"
      assert lexer2.str == "[mailto:test@example.com]]"
    end

    test "broken wikilink - 以 news 开头 [[news:example.com]]" do
      # 测试 broken wikilink：以 news 开头的外链
      lexer = Lexer.new("[[news:example.com]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[news:example.com]]"
      assert lexer2.str == "[news:example.com]]"
    end

    test "broken wikilink - 以 // 开头 [[//example.com]]" do
      # 测试 broken wikilink：以 // 开头的协议相对链接
      lexer = Lexer.new("[[//example.com]]")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[//example.com]]"
      assert lexer2.str == "[//example.com]]"
    end

    test "未闭合的 wikilink [[target" do
      # 测试未闭合的 wikilink 应该按 broken 处理
      lexer = Lexer.new("[[target")

      # 第一个 token: 单个 '[' 文本
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :text
      assert token1.raw == "["

      # 剩余的应该是 "[target"
      assert lexer2.str == "[target"
    end

    test "wikilink 后面有其他内容" do
      # 测试 wikilink 后面还有其他文本
      lexer = Lexer.new("[[HomePage]]后面的文本")

      # 第一个 token: wikilink
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :self_closing
      assert token1.tag == "wikilink"
      assert token1.options.href == "HomePage"

      # 剩余的应该是 "后面的文本"
      assert lexer2.str == "后面的文本"
    end

    test "带空格的 target 会被 trim" do
      # 测试 target 中的空格会被去除
      lexer = Lexer.new("[[ HomePage ]]")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.tag == "wikilink"
      # 应该被 trim
      assert token.options.href == "HomePage"
    end

    test "pipe trick - 仅包含空白和注释的显示内容" do
      # 测试 pipe trick：显示内容仅包含空白或HTML注释
      lexer = Lexer.new("[[HomePage|   <!-- 注释 -->   ]]")

      # 应该还原为文本序列
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "[["

      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "HomePage"

      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "|"

      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :text
      assert token4.raw == "   <!-- 注释 -->   "

      {token5, _lexer6} = Lexer.next(lexer5)
      assert token5.type == :text
      assert token5.raw == "]]"
    end

    test "复杂的 wikilink 内容" do
      # 测试复杂的内容，包含特殊字符
      lexer = Lexer.new("[[Category:Programming|编程相关]]")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.tag == "wikilink"
      assert token.options.href == "Category:Programming"
      assert token.options.contents == ["编程相关"]
      assert token.options.firstPipeSrc == "|"
    end

    test "嵌套方括号的情况" do
      # 测试内容中包含方括号的情况
      lexer = Lexer.new("[[HomePage|[首页]]]")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.tag == "wikilink"
      assert token.options.href == "HomePage"
      # 最后一个 ] 被当作 wikilink 的结束符
      assert token.options.contents == ["[首页"]
    end

    test "多行的 wikilink" do
      # 测试跨多行的 wikilink
      input =
        """
        [[HomePage|这是一个
        跨多行的
        链接内容]]
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.tag == "wikilink"
      assert token.options.href == "HomePage"
      assert token.options.contents == ["这是一个\n跨多行的\n链接内容"]
    end
  end
end
