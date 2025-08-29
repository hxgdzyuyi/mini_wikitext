defmodule MiniWikitext.Lexer.HeadingTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "heading_rule 测试" do
    test "有闭合等号对的标题 - 层级取两边等号长度的最小值" do
      # 测试 ==标题== (层级 2)
      lexer = Lexer.new("==标题==")
      {tag_open, lexer2} = Lexer.next(lexer)

      assert tag_open.type == :open
      assert tag_open.raw == "=="
      assert tag_open.tag == "h2"
      assert tag_open.options == %{}

      # 下一个应该是文本内容
      {text_token, lexer3} = Lexer.next(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "标题"

      # 然后是闭合标签
      {tag_close, _lexer4} = Lexer.next(lexer3)
      assert tag_close.type == :close
      assert tag_close.raw == "=="
      assert tag_close.tag == "h2"
    end

    test "无闭合等号的标题" do
      # 测试 ===标题 (左侧3个等号，层级为 floor((3-1)/2) = 1)
      lexer = Lexer.new("===标题")
      {_text, lexer2} = Lexer.next(lexer)
      {_text, lexer3} = Lexer.next(lexer2)
      {_text, lexer4} = Lexer.next(lexer3)
      {text, lexer5} = Lexer.next(lexer4)

      assert text.type == :text
      assert text.raw == "标题"
    end

    test "层级最大为6的限制" do
      # 测试 ========标题======== (两边都是8个等号，但层级最大为6)
      lexer = Lexer.new("========标题========")
      {tag_open, lexer2} = Lexer.next(lexer)

      assert tag_open.type == :open
      assert tag_open.raw == "======"
      assert tag_open.tag == "h6"
      assert tag_open.options == %{}

      # 下一个应该是文本内容（包含多余的等号）
      {text_token, lexer3} = Lexer.next(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "==标题=="

      # 然后是闭合标签
      {tag_close, _lexer4} = Lexer.next(lexer3)
      assert tag_close.type == :close
      assert tag_close.raw == "======"
      assert tag_close.tag == "h6"
    end

    test "多出来的等号并入内容文本" do
      # 测试 ====标题== (左侧4个，右侧2个，层级为min(4,2)=2，多余的等号并入内容)
      lexer = Lexer.new("====标题==")
      {tag_open, lexer2} = Lexer.next(lexer)

      assert tag_open.type == :open
      assert tag_open.raw == "=="
      assert tag_open.tag == "h2"
      assert tag_open.options == %{}

      # 下一个应该是文本内容（包含左侧多余的等号）
      {text_token, lexer3} = Lexer.next(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "==标题"

      # 然后是闭合标签
      {tag_close, _lexer4} = Lexer.next(lexer3)
      assert tag_close.type == :close
      assert tag_close.raw == "=="
      assert tag_close.tag == "h2"
    end

    test "标题右侧的空格Tab与HTML注释" do
      # 测试 ==标题==   <!-- 注释 -->
      lexer = Lexer.new("==标题==   <!-- 注释 -->")
      {tag_open, lexer2} = Lexer.next(lexer)

      assert tag_open.type == :open
      assert tag_open.raw == "=="
      assert tag_open.tag == "h2"
      assert tag_open.options == %{}

      # 下一个应该是文本内容
      {text_token, lexer3} = Lexer.next(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "标题"

      # 然后是闭合标签
      {tag_close, lexer4} = Lexer.next(lexer3)
      assert tag_close.type == :close
      assert tag_close.raw == "=="
      assert tag_close.tag == "h2"

      # 接下来是空格token
      {space_token, lexer5} = Lexer.next(lexer4)
      assert space_token.type == :space
      assert space_token.raw == "   "

      # 最后是HTML注释token
      {comment_token, _lexer6} = Lexer.next(lexer5)
      assert comment_token.type == :html_comment
      assert comment_token.raw == "<!-- 注释 -->"
    end
  end
end
