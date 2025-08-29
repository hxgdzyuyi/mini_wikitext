defmodule MiniWikitext.Lexer.HtmlCommentTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "HTML 注释测试" do
    test "闭合的 HTML 注释 <!-- ... -->" do
      # 测试基本的闭合注释
      lexer = Lexer.new("<!-- 这是一个注释 -->")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == "<!-- 这是一个注释 -->"
      assert token.lineno == 1
      assert token.column == 1
    end

    test "未闭合的 HTML 注释 <!-- ..." do
      # 测试未闭合的注释，整个剩余部分都被当作注释
      lexer = Lexer.new("<!-- 这是一个未闭合的注释")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == "<!-- 这是一个未闭合的注释"
      assert token.lineno == 1
      assert token.column == 1
    end

    test "多行闭合的 HTML 注释" do
      # 测试跨多行的闭合注释
      input =
        """
        <!-- 这是一个
        多行的
        注释 -->
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == input
      assert token.lineno == 1
      assert token.column == 1
    end

    test "多行未闭合的 HTML 注释" do
      # 测试跨多行的未闭合注释
      input =
        """
        <!-- 这是一个
        多行的未闭合
        注释
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == input
      assert token.lineno == 1
      assert token.column == 1
    end

    test "注释后面还有其他内容（闭合注释）" do
      # 测试注释后面还有其他文本的情况
      lexer = Lexer.new("<!-- 注释 -->后面的文本")
      {comment_token, lexer2} = Lexer.advance(lexer)

      assert comment_token.type == :html_comment
      assert comment_token.raw == "<!-- 注释 -->"

      # 检查剩余的 lexer 状态
      assert lexer2.str == "后面的文本"
    end

    test "注释后面还有其他内容（未闭合注释）" do
      # 测试未闭合注释会消耗所有剩余内容
      lexer = Lexer.new("<!-- 未闭合注释 后面的内容也会被包含")
      {comment_token, lexer2} = Lexer.advance(lexer)

      assert comment_token.type == :html_comment
      assert comment_token.raw == "<!-- 未闭合注释 后面的内容也会被包含"

      # 检查剩余的 lexer 状态 - 应该为空
      assert lexer2.str == ""
    end

    test "空的 HTML 注释" do
      # 测试空注释
      lexer = Lexer.new("<!---->")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == "<!---->"
    end

    test "注释中包含特殊字符" do
      # 测试注释中包含各种特殊字符
      lexer = Lexer.new("<!-- 注释中有 <tag> 和 & 符号以及 \"引号\" -->")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == "<!-- 注释中有 <tag> 和 & 符号以及 \"引号\" -->"
    end

    test "注释中包含多个 -- 但只有最后的 --> 才是结束" do
      # 测试注释中包含 -- 但不是结束标记的情况
      lexer = Lexer.new("<!-- 这里有-- 一些--连字符 但只有最后的才结束 -->")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == "<!-- 这里有-- 一些--连字符 但只有最后的才结束 -->"
    end

    test "嵌套样式的注释内容" do
      # 测试注释中包含看起来像嵌套的内容
      lexer = Lexer.new("<!-- 外层注释 <!-- 看起来像内层 --> 实际结束 -->")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :html_comment
      assert token.raw == "<!-- 外层注释 <!-- 看起来像内层 -->"

      # 剩余部分应该是 " 实际结束 -->"
      assert lexer2.str == " 实际结束 -->"
    end
  end
end
