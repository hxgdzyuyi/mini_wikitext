defmodule MiniWikitext.Lexer.SpaceTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "space_rule 测试" do
    test "单个空格匹配" do
      # 测试单个空格的匹配（后面跟非空白字符避免被 trim_trailing_ws_keep_final_nl 处理）
      lexer = Lexer.new(" a")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.raw == " "
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容
      assert lexer2.str == "a"
    end

    test "多个空格匹配" do
      # 测试连续多个空格的匹配（后面跟非空白字符避免被 trim_trailing_ws_keep_final_nl 处理）
      lexer = Lexer.new("   b")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.raw == "   "
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容
      assert lexer2.str == "b"
    end

    test "单个制表符匹配" do
      # 测试单个制表符的匹配（后面跟非空白字符避免被 trim_trailing_ws_keep_final_nl 处理）
      lexer = Lexer.new("\tc")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.raw == "\t"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容
      assert lexer2.str == "c"
    end

    test "多个制表符匹配" do
      # 测试连续多个制表符的匹配（后面跟非空白字符避免被 trim_trailing_ws_keep_final_nl 处理）
      lexer = Lexer.new("\t\t\td")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.raw == "\t\t\t"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容
      assert lexer2.str == "d"
    end

    test "空格和制表符混合匹配" do
      # 测试空格和制表符混合的匹配（后面跟非空白字符避免被 trim_trailing_ws_keep_final_nl 处理）
      lexer = Lexer.new(" \t \t e")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.raw == " \t \t "
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容
      assert lexer2.str == "e"
    end

    test "空格后跟其他内容" do
      # 测试空格后面还有其他内容的情况
      lexer = Lexer.new("  hello")
      {space_token, lexer2} = Lexer.advance(lexer)

      assert space_token.type == :space
      assert space_token.raw == "  "

      # 检查剩余内容
      assert lexer2.str == "hello"

      # 获取下一个 token
      {text_token, _lexer3} = Lexer.advance(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "hello"
    end

    test "制表符后跟其他内容" do
      # 测试制表符后面还有其他内容的情况
      lexer = Lexer.new("\t\tworld")
      {space_token, lexer2} = Lexer.advance(lexer)

      assert space_token.type == :space
      assert space_token.raw == "\t\t"

      # 检查剩余内容
      assert lexer2.str == "world"

      # 获取下一个 token
      {text_token, _lexer3} = Lexer.advance(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "world"
    end

    test "空格遇到换行符停止" do
      # 测试空格匹配遇到换行符时停止
      lexer = Lexer.new("  \nhello")
      {space_token, lexer2} = Lexer.advance(lexer)

      assert space_token.type == :space
      assert space_token.raw == "  "

      # 检查剩余内容应该包含换行符
      assert lexer2.str == "\nhello"

      # 下一个 token 应该是换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline
      assert newline_token.raw == "\n"
      assert lexer3.str == "hello"
    end

    test "制表符遇到换行符停止" do
      # 测试制表符匹配遇到换行符时停止
      lexer = Lexer.new("\t\t\nworld")
      {space_token, lexer2} = Lexer.advance(lexer)

      assert space_token.type == :space
      assert space_token.raw == "\t\t"

      # 检查剩余内容应该包含换行符
      assert lexer2.str == "\nworld"

      # 下一个 token 应该是换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline
      assert newline_token.raw == "\n"
      assert lexer3.str == "world"
    end

    test "空格遇到特殊字符停止" do
      # 测试空格匹配遇到特殊字符时停止
      special_chars = ["<", "[", "]", "{", "}", "|", "!", "'", "="]

      for char <- special_chars do
        input = "  #{char}test"
        lexer = Lexer.new(input)
        {space_token, lexer2} = Lexer.advance(lexer)

        assert space_token.type == :space
        assert space_token.raw == "  "
        assert lexer2.str == "#{char}test"
      end
    end

    test "不匹配非空白字符开头的字符串" do
      # 测试以非空白字符开头的字符串不会被 space_rule 匹配
      # 这些情况下 space_rule 应该返回 nil，让其他规则处理

      non_space_inputs = [
        "hello world",
        "abc",
        "123",
        "<tag>",
        "[link]",
        "{template}",
        # 换行符开头
        "\nhello",
        # 空字符串
        ""
      ]

      for input <- non_space_inputs do
        lexer = Lexer.new(input)
        {token, _lexer2} = Lexer.advance(lexer)

        # space_rule 不应该匹配这些输入，应该由其他规则处理
        refute token.type == :space
      end
    end

    test "空格与文本的交替序列" do
      # 测试空格和文本交替出现的情况
      # 使用特殊字符来分隔，避免被 text_rule 连续匹配
      lexer = Lexer.new("  hello<world")

      # 第一个 token: 空格
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :space
      assert token1.raw == "  "

      # 第二个 token: "hello"
      {token2, lexer3} = Lexer.advance(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: "<"
      {token3, lexer4} = Lexer.advance(lexer3)
      assert token3.type == :text
      assert token3.raw == "<"

      # 第四个 token: "world"
      {token4, _lexer5} = Lexer.advance(lexer4)
      assert token4.type == :text
      assert token4.raw == "world"
    end

    test "制表符与文本的交替序列" do
      # 测试制表符和文本交替出现的情况
      # 使用特殊字符来分隔，避免被 text_rule 连续匹配
      lexer = Lexer.new("\thello[world")

      # 第一个 token: 制表符
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :space
      assert token1.raw == "\t"

      # 第二个 token: "hello"
      {token2, lexer3} = Lexer.advance(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: "["
      {token3, lexer4} = Lexer.advance(lexer3)
      assert token3.type == :text
      assert token3.raw == "["

      # 第四个 token: "world"
      {token4, _lexer5} = Lexer.advance(lexer4)
      assert token4.type == :text
      assert token4.raw == "world"
    end

    test "复杂的空白字符组合" do
      # 测试复杂的空白字符组合（后面跟非空白字符避免被 trim_trailing_ws_keep_final_nl 处理）
      lexer = Lexer.new(" \t  \t \t  f")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.raw == " \t  \t \t  "
      assert lexer2.str == "f"
    end

    test "位置信息正确设置" do
      # 测试 token 的行号和列号信息正确设置
      lexer = Lexer.new("   g")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :space
      assert token.lineno == 1
      assert token.column == 1
    end

    test "空格 token 在词法分析流程中的优先级" do
      # 测试 space_rule 在 advance 函数中的调用顺序
      # space_rule 应该在 text_rule 之前被调用

      lexer = Lexer.new("   text")

      # 第一个应该是空格 token，而不是文本 token
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :space
      assert token1.raw == "   "

      # 第二个才是文本 token
      {token2, _lexer3} = Lexer.advance(lexer2)
      assert token2.type == :text
      assert token2.raw == "text"
    end

    test "空格不会与 HTML 注释冲突" do
      # 测试空格不会与 HTML 注释规则冲突
      lexer = Lexer.new("  <!-- comment -->")

      # 第一个 token 应该是空格
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :space
      assert token1.raw == "  "

      # 第二个 token 应该是 HTML 注释
      {token2, _lexer3} = Lexer.advance(lexer2)
      assert token2.type == :html_comment
      assert token2.raw == "<!-- comment -->"
    end

    test "空格不会与 nowiki 标签冲突" do
      # 测试空格不会与 nowiki 标签规则冲突
      lexer = Lexer.new("  <nowiki>content</nowiki>")

      # 第一个 token 应该是空格
      {token1, lexer2} = Lexer.advance(lexer)
      assert token1.type == :space
      assert token1.raw == "  "

      # 第二个 token 应该是 nowiki 开始标签
      {token2, _lexer3} = Lexer.advance(lexer2)
      assert token2.type == :open
      assert token2.raw == "<nowiki>"
    end
  end
end
