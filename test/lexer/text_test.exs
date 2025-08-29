defmodule MiniWikitext.Lexer.TextTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "text_rule 测试" do
    test "基本文本匹配 - 普通字符" do
      # 测试基本的文本字符串匹配
      lexer = Lexer.new("hello world")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "hello world"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容为空
      assert lexer2.str == ""
    end

    test "中文文本匹配" do
      # 测试中文字符的匹配
      lexer = Lexer.new("你好世界")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "你好世界"
      assert token.lineno == 1
      assert token.column == 1
    end

    test "数字和字母混合文本" do
      # 测试数字、字母、符号的混合文本
      lexer = Lexer.new("abc123def456")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "abc123def456"
    end

    test "包含允许的特殊字符" do
      # 测试包含允许的特殊字符（不在排除列表中的字符）
      lexer = Lexer.new("text with spaces and punctuation.,;:?")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text with spaces and punctuation.,;:?"
    end

    test "遇到换行符时停止" do
      # 测试遇到换行符时文本匹配停止
      lexer = Lexer.new("hello\nworld")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "hello"
      assert lexer2.str == "\nworld"
    end

    test "遇到 < 字符时停止" do
      # 测试遇到 < 字符时文本匹配停止
      lexer = Lexer.new("text<tag>")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "<tag>"
    end

    test "遇到方括号时停止" do
      # 测试遇到 [ 或 ] 字符时文本匹配停止
      lexer = Lexer.new("text[link]")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "[link]"

      # 测试右方括号
      lexer3 = Lexer.new("text]end")
      {token3, lexer4} = Lexer.advance(lexer3)

      assert token3.type == :text
      assert token3.raw == "text"
      assert lexer4.str == "]end"
    end

    test "遇到花括号时停止" do
      # 测试遇到 { 或 } 字符时文本匹配停止
      lexer = Lexer.new("text{template}")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "{template}"

      # 测试右花括号
      lexer3 = Lexer.new("text}end")
      {token3, lexer4} = Lexer.advance(lexer3)

      assert token3.type == :text
      assert token3.raw == "text"
      assert lexer4.str == "}end"
    end

    test "遇到管道符时停止" do
      # 测试遇到 | 字符时文本匹配停止
      lexer = Lexer.new("text|pipe")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "|pipe"
    end

    test "遇到感叹号时停止" do
      # 测试遇到 ! 字符时文本匹配停止
      lexer = Lexer.new("text!exclamation")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "!exclamation"
    end

    test "遇到单引号时停止" do
      # 测试遇到 ' 字符时文本匹配停止
      lexer = Lexer.new("text'quote")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "'quote"
    end

    test "遇到等号时停止" do
      # 测试遇到 = 字符时文本匹配停止
      lexer = Lexer.new("text=equals")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "text"
      assert lexer2.str == "=equals"
    end

    test "单个特殊字符的回退处理" do
      # 测试当遇到单个特殊字符时，返回该字符作为 text token
      special_chars = ["<", "[", "{", "|", "!", "'"]

      for char <- special_chars do
        lexer = Lexer.new(char)
        {token, lexer2} = Lexer.advance(lexer)

        assert token.type == :text
        assert token.raw == char
        assert lexer2.str == ""
      end
    end

    test "单个特殊字符后跟其他内容" do
      # 测试单个特殊字符后面还有其他内容的情况
      lexer = Lexer.new("<hello")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "<"
      assert lexer2.str == "hello"
    end

    test "空字符串返回 eos" do
      # 测试空字符串时返回 :eof token
      lexer = Lexer.new("")
      {token, _lexer} = Lexer.advance(lexer)

      # 注意：根据代码实现，空字符串在 text_rule 中返回 :eos，但在 advance 中会被 eos_rule 捕获返回 :eof
      assert token.type == :eof
    end

    test "多字节 UTF-8 字符处理" do
      # 测试多字节 UTF-8 字符的正确处理
      lexer = Lexer.new("😀🎉中文测试")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "😀🎉中文测试"
    end

    test "单个多字节字符的回退处理" do
      # 测试单个多字节字符在特殊情况下的处理
      lexer = Lexer.new("😀<tag>")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "😀"
      assert lexer2.str == "<tag>"
    end

    test "位置信息正确设置" do
      # 测试 token 的行号和列号信息正确设置
      lexer = Lexer.new("hello")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.lineno == 1
      assert token.column == 1
    end

    test "包含制表符和空格的文本" do
      # 测试包含制表符和空格的文本
      lexer = Lexer.new("hello\tworld with spaces")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :text
      assert token.raw == "hello\tworld with spaces"
    end
  end
end
