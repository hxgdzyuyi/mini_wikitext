defmodule MiniWikitext.Lexer.NonCommentTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "非 HTML 注释情况" do
    test "不是以 <!-- 开头的内容不应该被识别为注释" do
      # 测试不匹配注释模式的情况
      lexer = Lexer.new("普通文本")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该不是 html_comment 类型
      refute token.type == :html_comment
    end

    test "只有 < 但不是完整的注释开始标记" do
      lexer = Lexer.new("< 不是注释")
      {token, _lexer} = Lexer.advance(lexer)

      refute token.type == :html_comment
    end

    test "类似注释但不完整的标记" do
      # 测试各种不完整的注释开始标记
      test_cases = [
        "<",
        "<!",
        "<!-",
        "<! --"
      ]

      Enum.each(test_cases, fn input ->
        lexer = Lexer.new(input)
        {token, _lexer} = Lexer.advance(lexer)

        # 这些都不应该被识别为 html_comment
        refute token.type == :html_comment, "输入 '#{input}' 被错误识别为 html_comment"
      end)
    end

    test "有效的未闭合注释会被识别" do
      # 这个测试确认 <!-- 开头的内容会被正确识别为注释，即使没有结束标记
      lexer = Lexer.new("<!-- 这是有效的未闭合注释")
      {token, _lexer} = Lexer.advance(lexer)

      # 这应该被识别为 html_comment
      assert token.type == :html_comment
      assert token.raw == "<!-- 这是有效的未闭合注释"
    end

    test "注释标记出现在文本中间" do
      # 测试当 <!-- 不在开头时的情况
      lexer = Lexer.new("文本 <!-- 这不是开头的注释")
      {token, _lexer} = Lexer.advance(lexer)

      # 第一个 token 不应该是 html_comment（因为不是从开头开始）
      refute token.type == :html_comment
    end
  end
end
