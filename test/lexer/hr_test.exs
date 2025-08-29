defmodule MiniWikitext.Lexer.HrTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "hr_rule 测试" do
    test "基本的4个连字符水平线" do
      # 测试基本的4个连字符在行首的情况
      lexer = Lexer.new("----")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容应该为空（因为输入被完全消耗）
      {eof_token, _} = Lexer.advance(lexer2)
      assert eof_token.type == :eof
    end

    test "5个连字符水平线" do
      # 测试5个连字符的情况
      lexer = Lexer.new("-----")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "-----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1
    end

    test "更多连字符水平线" do
      # 测试更多连字符的情况
      lexer = Lexer.new("----------")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "----------"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1
    end

    test "水平线后跟空格" do
      # 测试连字符后面跟空格的情况
      # 注意：trim_trailing_ws_keep_final_nl 会将尾随空白替换为换行符
      lexer = Lexer.new("---- ")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容（尾随空白被替换为换行符）
      assert lexer2.str == "\n"
    end

    test "水平线后跟制表符" do
      # 测试连字符后面跟制表符的情况
      # 注意：trim_trailing_ws_keep_final_nl 会将尾随空白替换为换行符
      lexer = Lexer.new("----\t")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容（尾随空白被替换为换行符）
      assert lexer2.str == "\n"
    end

    test "水平线后跟多个空白字符" do
      # 测试连字符后面跟多个空白字符的情况
      # 注意：trim_trailing_ws_keep_final_nl 会将尾随空白替换为换行符
      lexer = Lexer.new("-----  \t  ")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "-----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容（尾随空白被替换为换行符）
      assert lexer2.str == "\n"
    end

    test "水平线后跟换行符" do
      # 测试连字符后面直接跟换行符的情况
      lexer = Lexer.new("----\n")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容
      assert lexer2.str == "\n"

      # 下一个 token 应该是换行符
      {newline_token, _} = Lexer.advance(lexer2)
      assert newline_token.type == :newline
    end

    test "水平线后跟空白再跟换行符" do
      # 测试连字符后面跟空白字符再跟换行符的情况
      # 注意：trim_trailing_ws_keep_final_nl 会将尾随空白替换为换行符
      lexer = Lexer.new("----  \n")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.raw == "----"
      assert token.tag == "hr"
      assert token.lineno == 1
      assert token.column == 1

      # 检查剩余内容（尾随空白被替换为换行符）
      assert lexer2.str == "\n"
    end

    test "水平线后跟其他文本（不匹配）" do
      # 测试连字符后面直接跟非空白字符的情况，应该不匹配 hr_rule
      lexer = Lexer.new("----text")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该不匹配 hr_rule，而是被当作文本处理
      assert token.type == :text
      assert token.raw == "----text"
      assert token.tag == nil
    end

    test "少于4个连字符不匹配" do
      # 测试少于4个连字符的情况，应该不匹配 hr_rule
      inputs = ["---", "--", "-"]

      for input <- inputs do
        lexer = Lexer.new(input)
        {token, _lexer} = Lexer.advance(lexer)

        # 应该不匹配 hr_rule，而是被当作文本处理
        assert token.type == :text
        assert token.raw == input
      end
    end

    test "非行首的连字符不匹配" do
      # 测试不在行首的连字符，应该不匹配 hr_rule
      lexer = Lexer.new("text----")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该不匹配 hr_rule，而是被当作文本处理
      assert token.type == :text
      assert token.raw == "text----"
      assert token.tag == nil
    end

    test "空格后的连字符不匹配" do
      # 测试前面有空格的连字符，应该不匹配 hr_rule
      lexer = Lexer.new(" ----")
      {space_token, lexer2} = Lexer.advance(lexer)

      # 第一个 token 应该是空格
      assert space_token.type == :space
      assert space_token.raw == " "

      # 第二个 token 应该是文本，因为现在不在行首了
      {text_token, _lexer3} = Lexer.advance(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "----"
    end

    test "制表符后的连字符不匹配" do
      # 测试前面有制表符的连字符，应该不匹配 hr_rule
      lexer = Lexer.new("\t----")
      {space_token, lexer2} = Lexer.advance(lexer)

      # 第一个 token 应该是空格（制表符）
      assert space_token.type == :space
      assert space_token.raw == "\t"

      # 第二个 token 应该是文本，因为现在不在行首了
      {text_token, _lexer3} = Lexer.advance(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "----"
    end

    test "换行后的连字符匹配" do
      # 测试换行符后的连字符，应该匹配 hr_rule（因为换行后重新回到行首）
      lexer = Lexer.new("text\n----")

      # 第一个 token: 文本
      {text_token, lexer2} = Lexer.advance(lexer)
      assert text_token.type == :text
      assert text_token.raw == "text"

      # 第二个 token: 换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline
      assert newline_token.raw == "\n"

      # 第三个 token: 水平线（因为现在在新行的行首）
      {hr_token, _lexer4} = Lexer.advance(lexer3)
      assert hr_token.type == :self_closing
      assert hr_token.raw == "----"
    end

    test "多行中的水平线" do
      # 测试多行文本中的水平线
      input =
        """
        第一行文本
        ----
        第三行文本
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个 token: "第一行文本"
      {text_token, lexer2} = Lexer.advance(lexer)
      assert text_token.type == :text
      assert text_token.raw == "第一行文本"

      # 第二个 token: 换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline

      # 第三个 token: 水平线
      {hr_token, lexer4} = Lexer.advance(lexer3)
      assert hr_token.type == :self_closing
      assert hr_token.raw == "----"

      # 第四个 token: 换行符
      {newline_token2, lexer5} = Lexer.advance(lexer4)
      assert newline_token2.type == :newline

      # 第五个 token: "第三行文本"
      {text_token2, _lexer6} = Lexer.advance(lexer5)
      assert text_token2.type == :text
      assert text_token2.raw == "第三行文本"
    end

    test "连续的水平线" do
      # 测试连续的多个水平线
      input =
        """
        ----
        -----
        ------
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个 token: 第一条水平线
      {hr1_token, lexer2} = Lexer.advance(lexer)
      assert hr1_token.type == :self_closing
      assert hr1_token.raw == "----"

      # 第二个 token: 换行符
      {newline1_token, lexer3} = Lexer.advance(lexer2)
      assert newline1_token.type == :newline

      # 第三个 token: 第二条水平线
      {hr2_token, lexer4} = Lexer.advance(lexer3)
      assert hr2_token.type == :self_closing
      assert hr2_token.raw == "-----"

      # 第四个 token: 换行符
      {newline2_token, lexer5} = Lexer.advance(lexer4)
      assert newline2_token.type == :newline

      # 第五个 token: 第三条水平线
      {hr3_token, _lexer6} = Lexer.advance(lexer5)
      assert hr3_token.type == :self_closing
      assert hr3_token.raw == "------"
    end

    test "水平线与其他特殊字符混合" do
      # 测试水平线与其他特殊字符的交互
      # 注意：hr_rule 要求连字符后面必须跟空白字符或行尾，所以需要在中间加空格
      lexer = Lexer.new("---- <!-- comment -->")

      # 第一个 token: 水平线
      {hr_token, lexer2} = Lexer.advance(lexer)
      assert hr_token.type == :self_closing
      assert hr_token.raw == "----"

      # 第二个 token: 空格
      {space_token, lexer3} = Lexer.advance(lexer2)
      assert space_token.type == :space
      assert space_token.raw == " "

      # 第三个 token: HTML 注释
      {comment_token, _lexer4} = Lexer.advance(lexer3)
      assert comment_token.type == :html_comment
      assert comment_token.raw == "<!-- comment -->"
    end

    test "水平线位置信息正确设置" do
      # 测试水平线 token 的行号和列号信息正确设置
      lexer = Lexer.new("----")
      {token, _lexer} = Lexer.advance(lexer)

      assert token.type == :self_closing
      assert token.lineno == 1
      assert token.column == 1
    end

    test "多行中水平线的位置信息" do
      # 测试多行中水平线的位置信息
      input =
        """
        文本
        ----
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过第一行的文本和换行符
      {_text_token, lexer2} = Lexer.advance(lexer)
      {_newline_token, lexer3} = Lexer.advance(lexer2)

      # 检查水平线的位置信息
      {hr_token, _lexer4} = Lexer.advance(lexer3)
      assert hr_token.type == :self_closing
      assert hr_token.raw == "----"
      # 第二行
      assert hr_token.lineno == 2
      # 第一列（行首）
      assert hr_token.column == 1
    end

    test "空行后的水平线" do
      # 测试空行后的水平线
      input =
        """
        文本

        ----
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过第一行的文本、第一个换行符、第二个换行符
      {_text_token, lexer2} = Lexer.advance(lexer)
      {_newline1_token, lexer3} = Lexer.advance(lexer2)
      {_newline2_token, lexer4} = Lexer.advance(lexer3)

      # 检查水平线
      {hr_token, _lexer5} = Lexer.advance(lexer4)
      assert hr_token.type == :self_closing
      assert hr_token.raw == "----"
      # 第三行
      assert hr_token.lineno == 3
      # 第一列（行首）
      assert hr_token.column == 1
    end

    test "hr_rule 在词法分析流程中的优先级" do
      # 测试 hr_rule 在 advance 函数中的调用顺序
      # hr_rule 应该在 text_rule 之前被调用
      lexer = Lexer.new("----")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该匹配 hr_rule，而不是被当作文本处理
      assert token.type == :self_closing
      assert token.raw == "----"
      assert token.tag == "hr"
    end
  end
end
