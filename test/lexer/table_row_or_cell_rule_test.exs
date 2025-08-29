defmodule MiniWikitext.Lexer.TableRowOrCellRuleTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "table_row_or_cell_rule 行标记测试 (|-)" do
    test "基本的行开始标记 |-" do
      # 测试在表格内的基本行开始标记
      input =
        """
        {|
        |- 
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个 token: 表格开始
      {table_open, lexer2} = Lexer.next(lexer)
      assert table_open.type == :open
      assert table_open.tag == "table"

      # 第二个 token: 换行符
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 第三个 token: 行开始
      {row_open, lexer4} = Lexer.next(lexer3)
      assert row_open.type == :open
      assert row_open.raw == "|-"
      assert row_open.tag == "tr"
      assert row_open.options == %{}
      assert row_open.lineno == 2
      assert row_open.column == 1

      # 检查栈状态 - 应该包含表格和行
      assert Enum.member?(lexer4.stack, "{|")
      assert Enum.member?(lexer4.stack, "tr")
    end

    test "带属性的行开始标记" do
      # 测试带属性的行开始标记
      input =
        """
        {|
        |- class=row id=myrow style="background:red"
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 行开始标记
      {row_open, _lexer4} = Lexer.next(lexer3)
      assert row_open.type == :open
      assert row_open.raw == "|-"
      assert row_open.tag == "tr"
      assert row_open.options.class == "row"
      assert row_open.options.id == "myrow"
      assert row_open.options.style == "background:red"
    end

    test "连续的行标记 - 自动关闭上一行" do
      # 测试连续的行标记会自动关闭上一行
      input =
        """
        {|
        |- class=row1
        |- class=row2
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 第一行开始
      {row1_open, lexer4} = Lexer.next(lexer3)
      assert row1_open.type == :open
      assert row1_open.tag == "tr"
      assert row1_open.options.class == "row1"

      # 换行符
      {_newline2, lexer5} = Lexer.next(lexer4)

      # 第二行开始 - 应该先返回第一行的关闭标记
      {row1_close, lexer6} = Lexer.next(lexer5)
      assert row1_close.type == :close
      assert row1_close.tag == "tr"
      assert row1_close.options == %{}

      # 然后是第二行开始
      {row2_open, _lexer7} = Lexer.next(lexer6)
      assert row2_open.type == :open
      assert row2_open.tag == "tr"
      assert row2_open.options.class == "row2"
    end
  end

  describe "table_row_or_cell_rule 数据格测试 (|)" do
    test "基本的数据格单元" do
      # 测试基本的数据格单元
      input =
        """
        {|
        | 单元格内容
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 隐式行开始（因为不在行内）
      {row_open, lexer4} = Lexer.next(lexer3)
      assert row_open.type == :open
      assert row_open.tag == "tr"
      assert row_open.options == %{}

      # 数据格开始
      {cell_open, lexer5} = Lexer.next(lexer4)
      assert cell_open.type == :open
      assert cell_open.raw == "|"
      assert cell_open.tag == "td"
      assert cell_open.options == %{}

      # 单元格内容
      {cell_text, lexer6} = Lexer.next(lexer5)
      assert cell_text.type == :text
      assert cell_text.raw == "单元格内容"

      # 数据格结束
      {cell_close, lexer7} = Lexer.next(lexer6)
      assert cell_close.type == :close
      assert cell_close.tag == "td"

      # 行结束
      {row_close, _lexer8} = Lexer.next(lexer7)
      assert row_close.type == :close
      assert row_close.tag == "tr"
    end

    test "带属性的数据格单元" do
      # 测试带属性的数据格单元
      input =
        """
        {|
        | class=cell style="color:blue" | 蓝色单元格
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 跳过隐式行开始
      {_row_open, lexer4} = Lexer.next(lexer3)

      # 数据格开始
      {cell_open, lexer5} = Lexer.next(lexer4)
      assert cell_open.type == :open
      assert cell_open.raw == "|"
      assert cell_open.tag == "td"
      assert cell_open.options.class == "cell"
      assert cell_open.options.style == "color:blue"

      # 单元格内容
      {cell_text, _lexer6} = Lexer.next(lexer5)
      assert cell_text.type == :text
      assert cell_text.raw == "蓝色单元格"
    end

    test "多个数据格单元用 || 分隔" do
      # 测试同一行中多个数据格单元
      input =
        """
        {|
        | 单元格1 || 单元格2 || 单元格3
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始、换行符、隐式行开始
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)
      {_row_open, lexer4} = Lexer.next(lexer3)

      # 第一个单元格
      {cell1_open, lexer5} = Lexer.next(lexer4)
      assert cell1_open.type == :open
      assert cell1_open.raw == "|"
      assert cell1_open.tag == "td"

      {cell1_text, lexer6} = Lexer.next(lexer5)
      assert cell1_text.type == :text
      assert cell1_text.raw == "单元格1"

      {cell1_close, lexer7} = Lexer.next(lexer6)
      assert cell1_close.type == :close
      assert cell1_close.tag == "td"

      # 第二个单元格
      {cell2_open, lexer8} = Lexer.next(lexer7)
      assert cell2_open.type == :open
      assert cell2_open.raw == "||"
      assert cell2_open.tag == "td"

      {cell2_text, lexer9} = Lexer.next(lexer8)
      assert cell2_text.type == :text
      assert cell2_text.raw == "单元格2"

      {cell2_close, lexer10} = Lexer.next(lexer9)
      assert cell2_close.type == :close
      assert cell2_close.tag == "td"

      # 第三个单元格
      {cell3_open, lexer11} = Lexer.next(lexer10)
      assert cell3_open.type == :open
      assert cell3_open.raw == "||"
      assert cell3_open.tag == "td"

      {cell3_text, lexer12} = Lexer.next(lexer11)
      assert cell3_text.type == :text
      assert cell3_text.raw == "单元格3"

      {cell3_close, lexer13} = Lexer.next(lexer12)
      assert cell3_close.type == :close
      assert cell3_close.tag == "td"

      # 行结束
      {row_close, _lexer14} = Lexer.next(lexer13)
      assert row_close.type == :close
      assert row_close.tag == "tr"
    end
  end

  describe "table_row_or_cell_rule 表头格测试 (!)" do
    test "基本的表头格单元" do
      # 测试基本的表头格单元
      input =
        """
        {|
        ! 表头内容
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 隐式行开始
      {row_open, lexer4} = Lexer.next(lexer3)
      assert row_open.type == :open
      assert row_open.tag == "tr"

      # 表头格开始
      {header_open, lexer5} = Lexer.next(lexer4)
      assert header_open.type == :open
      assert header_open.raw == "!"
      assert header_open.tag == "th"
      assert header_open.options == %{}

      # 表头内容
      {header_text, lexer6} = Lexer.next(lexer5)
      assert header_text.type == :text
      assert header_text.raw == "表头内容"

      # 表头格结束
      {header_close, lexer7} = Lexer.next(lexer6)
      assert header_close.type == :close
      assert header_close.tag == "th"

      # 行结束
      {row_close, _lexer8} = Lexer.next(lexer7)
      assert row_close.type == :close
      assert row_close.tag == "tr"
    end

    test "带属性的表头格单元" do
      # 测试带属性的表头格单元
      input =
        """
        {|
        ! scope=col class=header | 列标题
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始、换行符、隐式行开始
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)
      {_row_open, lexer4} = Lexer.next(lexer3)

      # 表头格开始
      {header_open, lexer5} = Lexer.next(lexer4)
      assert header_open.type == :open
      assert header_open.raw == "!"
      assert header_open.tag == "th"
      assert header_open.options.scope == "col"
      assert header_open.options.class == "header"

      # 表头内容
      {header_text, _lexer6} = Lexer.next(lexer5)
      assert header_text.type == :text
      assert header_text.raw == "列标题"
    end

    test "多个表头格单元用 !! 分隔" do
      # 测试同一行中多个表头格单元
      input =
        """
        {|
        ! 表头1 !! 表头2 !! 表头3
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始、换行符、隐式行开始
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)
      {_row_open, lexer4} = Lexer.next(lexer3)

      # 第一个表头格
      {header1_open, lexer5} = Lexer.next(lexer4)
      assert header1_open.type == :open
      assert header1_open.raw == "!"
      assert header1_open.tag == "th"

      {header1_text, lexer6} = Lexer.next(lexer5)
      assert header1_text.raw == "表头1"

      {header1_close, lexer7} = Lexer.next(lexer6)
      assert header1_close.type == :close
      assert header1_close.tag == "th"

      # 第二个表头格
      {header2_open, lexer8} = Lexer.next(lexer7)
      assert header2_open.type == :open
      assert header2_open.raw == "!!"
      assert header2_open.tag == "th"

      {header2_text, lexer9} = Lexer.next(lexer8)
      assert header2_text.raw == "表头2"

      {header2_close, lexer10} = Lexer.next(lexer9)
      assert header2_close.type == :close
      assert header2_close.tag == "th"

      # 第三个表头格
      {header3_open, lexer11} = Lexer.next(lexer10)
      assert header3_open.type == :open
      assert header3_open.raw == "!!"
      assert header3_open.tag == "th"

      {header3_text, lexer12} = Lexer.next(lexer11)
      assert header3_text.raw == "表头3"

      {header3_close, lexer13} = Lexer.next(lexer12)
      assert header3_close.type == :close
      assert header3_close.tag == "th"

      # 行结束
      {row_close, _lexer14} = Lexer.next(lexer13)
      assert row_close.type == :close
      assert row_close.tag == "tr"
    end
  end

  describe "table_row_or_cell_rule 边界情况测试" do
    test "必须在表格内才能匹配" do
      # 测试不在表格内的行和单元格标记不应该匹配
      test_cases = ["|-", "| 单元格", "! 表头"]

      for input <- test_cases do
        lexer = Lexer.new(input)
        {token, _lexer} = Lexer.advance(lexer)

        # 应该被当作文本处理
        assert token.type == :text
      end
    end

    test "必须在行首才能匹配" do
      # 测试不在行首的标记不应该匹配
      input =
        """
        {|
        text|- 不在行首
        text| 不在行首
        text! 不在行首
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始和换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {newline1, lexer3} = Lexer.next(lexer2)

      # 第一行应该被当作文本处理
      {text1_token, lexer4} = Lexer.next(lexer3)
      assert text1_token.type == :text
      assert text1_token.raw == "text"

      # 跳过后续内容验证都是文本处理
      {text2_token, _lexer5} = Lexer.next(lexer4)
      assert text2_token.type == :text
    end

    test "空的单元格内容" do
      # 测试空的单元格内容
      input =
        """
        {|
        |
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始、换行符、隐式行开始
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)
      {_row_open, lexer4} = Lexer.next(lexer3)

      # 数据格开始
      {cell_open, lexer5} = Lexer.next(lexer4)
      assert cell_open.type == :open
      assert cell_open.tag == "td"

      # 应该直接是单元格结束（没有文本内容）
      {cell_close, lexer6} = Lexer.next(lexer5)
      assert cell_close.type == :close
      assert cell_close.tag == "td"

      # 行结束
      {row_close, _lexer7} = Lexer.next(lexer6)
      assert row_close.type == :close
      assert row_close.tag == "tr"
    end

    test "连续的表格数据单元格可以从新的一行开始，每个单元格使用单竖线（|）标记。" do
      # 测试在已存在行内添加单元格
      input =
        """
        {|
        |- class=myrow
        | 单元格1
        | 单元格2
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过表格开始、换行符
      {_table_open, lexer2} = Lexer.next(lexer)
      {_newline1, lexer3} = Lexer.next(lexer2)

      # 显式行开始
      {row_open, lexer4} = Lexer.next(lexer3)
      assert row_open.type == :open
      assert row_open.tag == "tr"
      assert row_open.options.class == "myrow"

      # 跳过换行符
      {_newline2, lexer5} = Lexer.next(lexer4)

      # 第一个单元格（在已存在的行内）
      {cell1_open, lexer6} = Lexer.next(lexer5)
      assert cell1_open.type == :open
      assert cell1_open.tag == "td"

      {cell1_text, lexer7} = Lexer.next(lexer6)
      assert cell1_text.raw == "单元格1"

      {cell1_close, lexer8} = Lexer.next(lexer7)
      assert cell1_close.type == :close
      assert cell1_close.tag == "td"

      {_newline, lexer9} = Lexer.next(lexer8)

      {cell2_open, lexer10} = Lexer.next(lexer9)
      assert cell2_open.type == :open
      assert cell2_open.tag == "td"

      {cell2_text, _lexer11} = Lexer.next(lexer10)
      assert cell2_text.raw == "单元格2"
    end
  end
end
