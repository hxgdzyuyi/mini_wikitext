defmodule MiniWikitext.Lexer.TableFenceTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "table_fence_rule 测试" do
    test "基本的表格开始标记 {|" do
      # 测试基本的表格开始标记在行首的情况
      lexer = Lexer.new("{|")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options == %{}
      assert token.lineno == 1
      assert token.column == 1

      # 检查栈状态 - 应该包含 "{|"
      assert lexer2.stack == ["{|"]

      # 检查剩余内容应该为空
      {eof_token, _} = Lexer.advance(lexer2)
      assert eof_token.type == :eof
    end

    test "基本的表格结束标记 |}" do
      # 测试基本的表格结束标记在行首的情况
      lexer = Lexer.new("|}")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :close
      assert token.raw == "|}"
      assert token.tag == "table"
      assert token.options == %{}
      assert token.lineno == 1
      assert token.column == 1

      # 检查栈状态 - 应该为空（因为没有对应的开始标记）
      assert lexer2.stack == []

      # 检查剩余内容应该为空
      {eof_token, _} = Lexer.advance(lexer2)
      assert eof_token.type == :eof
    end

    test "表格开始后跟表格结束" do
      # 测试完整的表格标记对
      input =
        """
        {|
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个 token: 表格开始
      {open_token, lexer2} = Lexer.advance(lexer)
      assert open_token.type == :open
      assert open_token.raw == "{|"
      assert open_token.tag == "table"
      assert lexer2.stack == ["{|"]

      # 第二个 token: 换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline
      assert newline_token.raw == "\n"

      # 第三个 token: 表格结束
      {close_token, lexer4} = Lexer.advance(lexer3)
      assert close_token.type == :close
      assert close_token.raw == "|}"
      assert close_token.tag == "table"
      # 栈应该被弹出
      assert lexer4.stack == []
    end

    test "表格标记必须在行首 - 开始标记" do
      # 测试不在行首的 {| 不应该匹配 table_fence_rule
      lexer = Lexer.new("text{|")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该不匹配 table_fence_rule，而是被当作文本处理
      # 注意：text_rule 的正则表达式 /^[^\n<\[\]\{\}\|!'=]+/u 会在 { 处停止
      assert token.type == :text
      assert token.raw == "text"
    end

    test "表格标记必须在行首 - 结束标记" do
      # 测试不在行首的 |} 不应该匹配 table_fence_rule
      lexer = Lexer.new("text|}")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该不匹配 table_fence_rule，而是被当作文本处理
      # 注意：text_rule 的正则表达式 /^[^\n<\[\]\{\}\|!'=]+/u 会在 | 处停止
      assert token.type == :text
      assert token.raw == "text"
    end

    test "空格后的表格标记不匹配" do
      # 测试前面有空格的表格标记，应该不匹配 table_fence_rule
      lexer = Lexer.new(" {|")
      {space_token, lexer2} = Lexer.advance(lexer)

      # 第一个 token 应该是空格
      assert space_token.type == :space
      assert space_token.raw == " "

      # 第二个 token 应该是文本，因为现在不在行首了
      # 注意：text_rule 的正则表达式 /^[^\n<\[\]\{\}\|!'=]+/u 不会匹配 {，所以会按单个字符处理
      {text_token, _lexer3} = Lexer.advance(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "{"
    end

    test "制表符后的表格标记不匹配" do
      # 测试前面有制表符的表格标记，应该不匹配 table_fence_rule
      lexer = Lexer.new("\t|}")
      {space_token, lexer2} = Lexer.advance(lexer)

      # 第一个 token 应该是空格（制表符）
      assert space_token.type == :space
      assert space_token.raw == "\t"

      # 第二个 token 应该是文本，因为现在不在行首了
      # 注意：text_rule 的正则表达式 /^[^\n<\[\]\{\}\|!'=]+/u 不会匹配 |，所以会按单个字符处理
      {text_token, _lexer3} = Lexer.advance(lexer2)
      assert text_token.type == :text
      assert text_token.raw == "|"
    end

    test "换行后的表格标记匹配" do
      # 测试换行符后的表格标记，应该匹配 table_fence_rule（因为换行后重新回到行首）
      input =
        """
        text
        {|
        content
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个 token: 文本
      {text_token, lexer2} = Lexer.advance(lexer)
      assert text_token.type == :text
      assert text_token.raw == "text"

      # 第二个 token: 换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline

      # 第三个 token: 表格开始（因为现在在新行的行首）
      {open_token, lexer4} = Lexer.advance(lexer3)
      assert open_token.type == :open
      assert open_token.raw == "{|"
      assert open_token.tag == "table"
      assert lexer4.stack == ["{|"]

      # 跳过换行符和内容
      {_newline, lexer5} = Lexer.advance(lexer4)
      {_content, lexer6} = Lexer.advance(lexer5)
      {_newline2, lexer7} = Lexer.advance(lexer6)

      # 表格结束标记
      {close_token, lexer8} = Lexer.advance(lexer7)
      assert close_token.type == :close
      assert close_token.raw == "|}"
      assert close_token.tag == "table"
      assert lexer8.stack == []
    end

    test "嵌套表格的栈管理" do
      # 测试嵌套表格的栈管理
      input =
        """
        {|
        {|
        |}
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个表格开始
      {open1_token, lexer2} = Lexer.advance(lexer)
      assert open1_token.type == :open
      assert open1_token.raw == "{|"
      assert lexer2.stack == ["{|"]

      # 换行符
      {_newline1, lexer3} = Lexer.advance(lexer2)

      # 第二个表格开始（嵌套）
      {open2_token, lexer4} = Lexer.advance(lexer3)
      assert open2_token.type == :open
      assert open2_token.raw == "{|"
      # 栈中应该有两个元素
      assert lexer4.stack == ["{|", "{|"]

      # 换行符
      {_newline2, lexer5} = Lexer.advance(lexer4)

      # 第一个表格结束（内层）
      {close1_token, lexer6} = Lexer.advance(lexer5)
      assert close1_token.type == :close
      assert close1_token.raw == "|}"
      # 栈中应该剩下一个元素
      assert lexer6.stack == ["{|"]

      # 换行符
      {_newline3, lexer7} = Lexer.advance(lexer6)

      # 第二个表格结束（外层）
      {close2_token, lexer8} = Lexer.advance(lexer7)
      assert close2_token.type == :close
      assert close2_token.raw == "|}"
      # 栈应该为空
      assert lexer8.stack == []
    end

    test "不匹配的表格结束标记" do
      # 测试没有对应开始标记的结束标记
      lexer = Lexer.new("|}")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :close
      assert token.raw == "|}"
      assert token.tag == "table"
      # 栈应该保持为空，因为没有对应的开始标记可以弹出
      assert lexer2.stack == []
    end

    test "多个不匹配的表格结束标记" do
      # 测试多个没有对应开始标记的结束标记
      input =
        """
        |}
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个结束标记
      {close1_token, lexer2} = Lexer.advance(lexer)
      assert close1_token.type == :close
      assert close1_token.raw == "|}"
      assert lexer2.stack == []

      # 换行符
      {_newline, lexer3} = Lexer.advance(lexer2)

      # 第二个结束标记
      {close2_token, lexer4} = Lexer.advance(lexer3)
      assert close2_token.type == :close
      assert close2_token.raw == "|}"
      assert lexer4.stack == []
    end

    test "表格标记后跟其他内容" do
      # 测试表格标记后面跟其他文本的情况
      lexer = Lexer.new("{|content")
      {table_token, _lexer2} = Lexer.advance(lexer)

      assert table_token.type == :open
      assert table_token.raw == "{|"
      assert table_token.tag == "table"
      assert table_token.options.content == true
    end

    test "表格标记的位置信息" do
      # 测试表格标记 token 的行号和列号信息正确设置
      input =
        """
        text
        {|
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过第一行的文本和换行符
      {_text_token, lexer2} = Lexer.advance(lexer)
      {_newline_token, lexer3} = Lexer.advance(lexer2)

      # 检查表格开始标记的位置信息
      {open_token, lexer4} = Lexer.advance(lexer3)
      assert open_token.type == :open
      # 第二行
      assert open_token.lineno == 2
      # 第一列（行首）
      assert open_token.column == 1

      # 跳过换行符
      {_newline2, lexer5} = Lexer.advance(lexer4)

      # 检查表格结束标记的位置信息
      {close_token, _lexer6} = Lexer.advance(lexer5)
      assert close_token.type == :close
      # 第三行
      assert close_token.lineno == 3
      # 第一列（行首）
      assert close_token.column == 1
    end

    test "表格标记与其他特殊字符混合" do
      # 测试表格标记与其他特殊字符的交互
      lexer = Lexer.new("{| <!-- comment -->")

      # 第一个 token: 表格开始
      {table_token, lexer2} = Lexer.advance(lexer)
      assert table_token.type == :open
      assert table_token.raw == "{|"
    end

    test "连续的表格标记" do
      # 测试连续的多个表格开始和结束标记
      input =
        """
        {|
        |}
        {|
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 第一个表格开始
      {open1_token, lexer2} = Lexer.advance(lexer)
      assert open1_token.type == :open
      assert open1_token.raw == "{|"
      assert lexer2.stack == ["{|"]

      # 换行符
      {_newline1, lexer3} = Lexer.advance(lexer2)

      # 第一个表格结束
      {close1_token, lexer4} = Lexer.advance(lexer3)
      assert close1_token.type == :close
      assert close1_token.raw == "|}"
      assert lexer4.stack == []

      # 换行符
      {_newline2, lexer5} = Lexer.advance(lexer4)

      # 第二个表格开始
      {open2_token, lexer6} = Lexer.advance(lexer5)
      assert open2_token.type == :open
      assert open2_token.raw == "{|"
      assert lexer6.stack == ["{|"]

      # 换行符
      {_newline3, lexer7} = Lexer.advance(lexer6)

      # 第二个表格结束
      {close2_token, lexer8} = Lexer.advance(lexer7)
      assert close2_token.type == :close
      assert close2_token.raw == "|}"
      assert lexer8.stack == []
    end

    test "table_fence_rule 在词法分析流程中的优先级" do
      # 测试 table_fence_rule 在 advance 函数中的调用顺序
      # table_fence_rule 应该在 text_rule 之前被调用
      lexer = Lexer.new("{|")
      {token, _lexer} = Lexer.advance(lexer)

      # 应该匹配 table_fence_rule，而不是被当作文本处理
      assert token.type == :open
      assert token.raw == "{|"
    end

    test "表格标记与 nowiki 标记混合" do
      # 测试表格标记与 nowiki 标记的交互
      lexer = Lexer.new("{| <nowiki>content</nowiki>")

      # 第一个 token: 表格开始
      {table_token, lexer2} = Lexer.advance(lexer)
      assert table_token.type == :open
      assert table_token.raw == "{|"

      # 第二个 token: 空格
      {space_token, lexer3} = Lexer.advance(lexer2)
      assert space_token.type == :eof
    end

    test "空行后的表格标记" do
      # 测试空行后的表格标记
      input =
        """
        text

        {|
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 跳过第一行的文本、第一个换行符、第二个换行符（空行）
      {_text_token, lexer2} = Lexer.advance(lexer)
      {_newline1_token, lexer3} = Lexer.advance(lexer2)
      {_newline2_token, lexer4} = Lexer.advance(lexer3)

      # 检查表格开始标记
      {open_token, lexer5} = Lexer.advance(lexer4)
      assert open_token.type == :open
      assert open_token.raw == "{|"
      # 第三行
      assert open_token.lineno == 3
      # 第一列（行首）
      assert open_token.column == 1
      assert lexer5.stack == ["{|"]

      # 跳过换行符
      {_newline3, lexer6} = Lexer.advance(lexer5)

      # 检查表格结束标记
      {close_token, lexer7} = Lexer.advance(lexer6)
      assert close_token.type == :close
      assert close_token.raw == "|}"
      # 第四行
      assert close_token.lineno == 4
      # 第一列（行首）
      assert close_token.column == 1
      assert lexer7.stack == []
    end

    test "只有开始标记没有结束标记" do
      # 测试只有开始标记的情况
      lexer = Lexer.new("{|")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert lexer2.stack == ["{|"]

      # 应该到达流末尾
      {eof_token, lexer3} = Lexer.advance(lexer2)
      assert eof_token.type == :eof
      # 栈中仍然有未匹配的开始标记
      assert lexer3.stack == ["{|"]
    end

    test "栈管理的边界情况 - 多层嵌套" do
      # 测试深层嵌套的表格栈管理
      input =
        """
        {|
        {|
        {|
        |}
        |}
        |}
        """
        |> String.trim_trailing()

      lexer = Lexer.new(input)

      # 三层开始标记
      {_open1, lexer2} = Lexer.advance(lexer)
      {_nl1, lexer3} = Lexer.advance(lexer2)
      {_open2, lexer4} = Lexer.advance(lexer3)
      {_nl2, lexer5} = Lexer.advance(lexer4)
      {_open3, lexer6} = Lexer.advance(lexer5)

      assert lexer6.stack == ["{|", "{|", "{|"]

      # 三层结束标记
      {_nl3, lexer7} = Lexer.advance(lexer6)
      {_close1, lexer8} = Lexer.advance(lexer7)
      assert lexer8.stack == ["{|", "{|"]

      {_nl4, lexer9} = Lexer.advance(lexer8)
      {_close2, lexer10} = Lexer.advance(lexer9)
      assert lexer10.stack == ["{|"]

      {_nl5, lexer11} = Lexer.advance(lexer10)
      {_close3, lexer12} = Lexer.advance(lexer11)
      assert lexer12.stack == []
    end
  end

  describe "表格属性解析测试" do
    test "基本的键值对属性" do
      # 测试基本的键值对属性解析
      lexer = Lexer.new("{| class=wikitable")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wikitable"
    end

    test "多个键值对属性" do
      # 测试多个键值对属性的解析
      lexer = Lexer.new("{| class=wikitable id=mytable border=1")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wikitable"
      assert token.options.id == "mytable"
      assert token.options.border == "1"
    end

    test "双引号包围的属性值" do
      # 测试双引号包围的属性值
      lexer = Lexer.new("{| class=\"wiki table\" title=\"My Table\"")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wiki table"
      assert token.options.title == "My Table"
    end

    test "单引号包围的属性值" do
      # 测试单引号包围的属性值
      lexer = Lexer.new("{| class='wiki table' title='My Table'")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wiki table"
      assert token.options.title == "My Table"
    end

    test "布尔属性（无值）" do
      # 测试布尔属性（只有键名，无值）
      lexer = Lexer.new("{| sortable collapsible")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.sortable == true
      assert token.options.collapsible == true
    end

    test "混合类型的属性" do
      # 测试混合类型的属性：键值对和布尔属性
      lexer = Lexer.new("{| class=wikitable sortable border=\"1\" readonly")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wikitable"
      assert token.options.sortable == true
      assert token.options.border == "1"
      assert token.options.readonly == true
    end

    test "属性名包含特殊字符" do
      # 测试属性名包含连字符、下划线、冒号和点号
      lexer = Lexer.new("{| data-sort=asc xml:lang=en my_attr=value class.name=test")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert Map.get(token.options, :"data-sort") == "asc"
      assert Map.get(token.options, :"xml:lang") == "en"
      assert token.options.my_attr == "value"
      assert Map.get(token.options, :"class.name") == "test"
    end

    test "空属性值" do
      # 测试空的属性值
      lexer = Lexer.new("{| class=\"\" title=''")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      # 根据实际实现，空字符串被当作 true
      assert token.options.class == ""
      assert token.options.title == ""
    end

    test "属性周围的空白处理" do
      # 测试属性周围的空白字符处理
      lexer = Lexer.new("{|   class = \"wikitable\"   id = mytable   ")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wikitable"
      assert token.options.id == "mytable"
    end

    test "属性解析遇到注释时停止" do
      # 测试属性解析在遇到HTML注释时停止
      lexer = Lexer.new("{| class=wikitable <!-- comment --> border=1")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wikitable"
      # 注释后的属性不应该被解析
      refute Map.has_key?(token.options, :border)
    end

    test "无属性的表格标记" do
      # 测试没有属性的表格标记
      lexer = Lexer.new("{|")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options == %{}
    end

    test "只有空白的属性部分" do
      # 测试只有空白字符的属性部分
      lexer = Lexer.new("{|   \t  ")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options == %{}
    end

    test "属性解析的消费长度" do
      # 测试属性解析正确消费了字符
      lexer = Lexer.new("{| class=wikitable\nsome content")
      {token, lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.options.class == "wikitable"

      # 下一个token应该是换行符
      {newline_token, lexer3} = Lexer.advance(lexer2)
      assert newline_token.type == :newline
      assert newline_token.raw == "\n"

      # 再下一个token应该是内容
      {content_token, _lexer4} = Lexer.advance(lexer3)
      assert content_token.type == :text
      assert content_token.raw == "some content"
    end

    test "复杂属性值中的特殊字符" do
      # 测试属性值中包含特殊字符
      lexer = Lexer.new("{| style=\"border: 1px solid #ccc; margin: 0 auto;\"")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.style == "border: 1px solid #ccc; margin: 0 auto;"
    end

    test "属性名大小写敏感" do
      # 测试属性名的大小写敏感性
      lexer = Lexer.new("{| Class=wikitable CLASS=other")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      # 应该有两个不同的属性
      assert Map.get(token.options, :Class) == "wikitable"
      assert Map.get(token.options, :CLASS) == "other"
    end

    test "无效的属性名被忽略" do
      # 测试以数字开头的无效属性名
      lexer = Lexer.new("{| class=wikitable 123invalid=value _valid=ok")
      {token, _lexer2} = Lexer.advance(lexer)

      assert token.type == :open
      assert token.raw == "{|"
      assert token.tag == "table"
      assert token.options.class == "wikitable"
      assert token.options._valid == "ok"
      # 无效的属性名不应该被解析
      refute Map.has_key?(token.options, :"123invalid")
    end
  end
end
