defmodule MiniWikitext.Lexer.TableCaptionTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "table_caption_rule 基本功能测试" do
    test "基本的表格标题 |+" do
      # 测试在表格内的基本表格标题标记
      input =
        """
        {|
        |+ 这是标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个 token: 表格开始
      {table_open, lexer2} = Lexer.next(lexer)
      assert table_open.type == :open
      assert table_open.tag == "table"

      # 第二个 token: 换行符
      {newline1, lexer3} = Lexer.next(lexer2)

      # 第三个 token: 表格标题
      {caption_token, lexer4} = Lexer.next(lexer3)
      assert caption_token.type == :open
      assert caption_token.raw == "|+"
      assert caption_token.tag == "table_caption"
      assert caption_token.options == %{}
      assert caption_token.lineno == 2
      assert caption_token.column == 1

      ## 第四个 token: 标题内容文本
      {text_token, lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == "这是标题"

      # 第五个 token: 表格标题结束
      {caption_close, lexer6} = Lexer.next(lexer5)
      assert caption_close.type == :close
      assert caption_close.tag == "table_caption"

      # 第六个 token: 换行符
      {_newline2, lexer7} = Lexer.next(lexer6)

      # 第七个 token: 表格结束
      {table_close, _lexer8} = Lexer.next(lexer7)
      assert table_close.type == :close
      assert table_close.tag == "table"
    end

    test "空的表格标题" do
      # 测试没有内容的表格标题
      input =
        """
        {|
        |+
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"

      # 应该直接是标题结束（没有文本内容）
      {caption_close, _lexer5} = Lexer.next(lexer4)
      assert caption_close.type == :close
      assert caption_close.tag == "table_caption"
    end

    test "表格标题必须在行首" do
      # 测试不在行首的 |+ 不应该匹配
      input =
        """
        {|
        text|+标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 应该被当作文本处理，而不是表格标题
      {text_token, _lexer4} = Lexer.next(lexer3)
      assert text_token.type == :text
      assert text_token.raw == "text"
    end

    test "表格标题必须在表格内" do
      # 测试不在表格内的 |+ 不应该匹配
      lexer = Lexer.new("|+ 标题")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该被当作文本处理
      assert token.type == :text
      assert token.raw == "|"
    end

    test "空格后的表格标题不匹配" do
      # 测试前面有空格的表格标题
      input =
        """
        {|
         |+ 标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 第一个应该是空格
      {space_token, lexer4} = Lexer.next(lexer3)
      assert space_token.type == :space
      assert space_token.raw == " "

      # 第二个应该是文本，因为不在行首了
      {caption_open, _lexer5} = Lexer.next(lexer4)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
    end
  end

  describe "table_caption_rule 属性解析测试" do
    test "带属性的表格标题" do
      # 测试带属性的表格标题
      input =
        """
        {|
        |+ class=caption | 这是标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"
      assert caption_open.options.class == "caption"

      # 标题内容
      {text_token, lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == " 这是标题"

      # 标题结束
      {caption_close, _lexer6} = Lexer.next(lexer5)
      assert caption_close.type == :close
      assert caption_close.tag == "table_caption"
    end

    test "多个属性的表格标题" do
      # 测试多个属性的表格标题
      input =
        """
        {|
        |+ class=caption id=title style="color:red" | 红色标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"
      assert caption_open.options.class == "caption"
      assert caption_open.options.id == "title"
      assert caption_open.options.style == "color:red"

      # 标题内容
      {text_token, _lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == " 红色标题"
    end

    test "布尔属性的表格标题" do
      # 测试布尔属性的表格标题
      input =
        """
        {|
        |+ hidden readonly | 隐藏标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"
      assert caption_open.options.hidden == true
      assert caption_open.options.readonly == true

      # 标题内容
      {text_token, _lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == " 隐藏标题"
    end

    test "只有属性没有内容的标题" do
      # 测试只有属性没有内容的标题
      input =
        """
        {|
        |+ class=caption |
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"
      assert caption_open.options.class == "caption"

      # 应该直接是标题结束（空内容）
      {caption_close, _lexer5} = Lexer.next(lexer4)
      assert caption_close.type == :close
      assert caption_close.tag == "table_caption"
    end
  end

  describe "table_caption_rule 内容处理测试" do
    test "标题内容中的特殊字符" do
      # 测试标题内容中包含特殊字符
      input =
        """
        {|
        |+ 标题<>&"'包含特殊字符
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"

      # 标题内容
      {text_token, _lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == "标题<>&\"'包含特殊字符"
    end

    test "标题内容包含管道符" do
      # 测试标题内容中包含管道符（非分隔符）
      input =
        """
        {|
        |+ class=caption | 内容包含|管道符|的标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题开始
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"
      assert caption_open.options.class == "caption"

      # 标题内容
      {text_token, _lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == " 内容包含|管道符|的标题"
    end
  end

  describe "table_caption_rule 边界情况测试" do
    test "表格结束后的标题不匹配" do
      # 测试表格结束后的|+不应该匹配
      input =
        """
        {|
        |}
        |+ 不在表格内的标题
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始、换行、表格结束、换行
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)
      {_table_close, lexer4} = Lexer.next(lexer3)
      {_newline2, lexer5} = Lexer.next(lexer4)

      # 应该被当作文本处理
      {text_token, _lexer6} = Lexer.next(lexer5)
      assert text_token.type == :text
      assert text_token.raw == "|"
    end

    test "标题中的管道符引号处理" do
      # 测试标题中引号内的管道符不被当作分隔符
      input =
        """
        {|
        |+ title="包含|管道符的标题" | 实际标题内容
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.raw == "|+"
      assert caption_open.tag == "table_caption"
      assert caption_open.options.title == "包含|管道符的标题"

      # 标题内容
      {text_token, _lexer5} = Lexer.next(lexer4)
      assert text_token.type == :text
      assert text_token.raw == " 实际标题内容"
    end

    test "空表格中的标题" do
      # 测试只包含标题的空表格
      input =
        """
        {|
        |+ 仅有标题的表格
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 表格标题
      {caption_open, lexer4} = Lexer.next(lexer3)
      assert caption_open.type == :open
      assert caption_open.tag == "table_caption"

      {caption_text, lexer5} = Lexer.next(lexer4)
      assert caption_text.raw == "仅有标题的表格"

      {caption_close, lexer6} = Lexer.next(lexer5)
      assert caption_close.type == :close
      assert caption_close.tag == "table_caption"

      # 跳过换行符
      {_newline2, lexer7} = Lexer.next(lexer6)

      # 表格结束
      {table_close, _lexer8} = Lexer.next(lexer7)
      assert table_close.type == :close
      assert table_close.tag == "table"
    end
  end
end
