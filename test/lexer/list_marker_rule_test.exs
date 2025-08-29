defmodule MiniWikitext.Lexer.ListMarkerRuleTest do
  use MiniWikitext.LexerCase, async: true

  describe "list_marker_rule 基本列表测试" do
    test "单个星号 - 无序列表项" do
      # 测试 *item
      lexer = Lexer.new("*item")

      # 第一个 token: 开启 ul
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "*"
      assert token1.tag == "ul"
      assert token1.options == %{}

      # 第二个 token: 开启 li
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "*"
      assert token2.tag == "li"
      assert token2.options == %{}

      # 第三个 token: text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "item"

      # 第四个 token: 关闭 li
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "li"
    end

    test "单个井号 - 有序列表项" do
      # 测试 #item
      lexer = Lexer.new("#item")

      # 第一个 token: 开启 ol
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "#"
      assert token1.tag == "ol"
      assert token1.options == %{}

      # 第二个 token: 开启 li
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "#"
      assert token2.tag == "li"
      assert token2.options == %{}

      # 第三个 token: text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "item"

      # 第四个 token: 关闭 li
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "li"
    end

    test "单个冒号 - 定义列表项 (dd)" do
      # 测试 :definition
      lexer = Lexer.new(":definition")

      # 第一个 token: 开启 dl
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == ":"
      assert token1.tag == "dl"
      assert token1.options == %{}

      # 第二个 token: 开启 dd
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == ":"
      assert token2.tag == "dd"
      assert token2.options == %{}

      # 第三个 token: text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "definition"

      # 第四个 token: 关闭 dd
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "dd"
    end

    test "空列表项" do
      # 测试 * (空内容)
      lexer = Lexer.new("*")

      # 第一个 token: 开启 ul
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "*"
      assert token1.tag == "ul"

      # 第二个 token: 开启 li
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "*"
      assert token2.tag == "li"

      # 第三个 token: 关闭 li (空内容直接关闭)
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :close
      assert token3.raw == ""
      assert token3.tag == "li"
    end
  end

  describe "list_marker_rule 嵌套列表测试" do
    test "二层嵌套 - 星号到井号" do
      # 测试 **item1 然后 *#item2
      lexer = Lexer.new("**item1")
      {tokens, _} = Lexer.collect_all_tokens(lexer)
      assert_token_at(tokens, 4, type: :text)
    end

    test "三层嵌套 - 混合类型" do
      # 测试 *#:item
      lexer = Lexer.new("*#:item")
      {tokens, _} = Lexer.collect_all_tokens(lexer)

      assert_token_at(tokens, 4, type: :open, tag: "dl")
    end
  end

  describe "list_marker_rule dtdd 功能测试" do
    test "分号开头的定义术语" do
      # 测试 ;term:definition
      lexer = Lexer.new(";term:definition")

      # 第一个 token: 开启 dl
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == ";"
      assert token1.tag == "dl"

      # 第二个 token: 开启 dt
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == ";"
      assert token2.tag == "dt"

      # 第三个 token: term text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "term"

      # 第四个 token: 关闭 dt
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "dt"

      # 第五个 token: 开启 dd
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :open
      assert token5.raw == ":"
      assert token5.tag == "dd"

      # 第六个 token: definition text
      {token6, lexer7} = Lexer.next(lexer6)
      assert token6.type == :text
      assert token6.raw == "definition"

      # 第七个 token: 关闭 dd
      {token7, _lexer8} = Lexer.next(lexer7)
      assert token7.type == :close
      assert token7.raw == ""
      assert token7.tag == "dd"
    end

    test "多个定义的dtdd" do
      # 测试 ;term:def1:def2
      lexer = Lexer.new(";term:def1:def2")

      # dl 开启
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.tag == "dl"

      # dt 开启
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.tag == "dt"

      # term
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "term"

      # dt 关闭
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.tag == "dt"

      # 第一个 dd 开启
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :open
      assert token5.tag == "dd"

      # def1
      {token6, lexer7} = Lexer.next(lexer6)
      assert token6.type == :text
      assert token6.raw == "def1"

      # 第一个 dd 关闭
      {token7, lexer8} = Lexer.next(lexer7)
      assert token7.type == :close
      assert token7.tag == "dd"

      # 第二个 dd 开启
      {token8, lexer9} = Lexer.next(lexer8)
      assert token8.type == :open
      assert token8.tag == "dd"

      # def2
      {token9, lexer10} = Lexer.next(lexer9)
      assert token9.type == :text
      assert token9.raw == "def2"

      # 第二个 dd 关闭
      {token10, _lexer11} = Lexer.next(lexer10)
      assert token10.type == :close
      assert token10.tag == "dd"
    end
  end

  describe "list_marker_rule hacky_dl_uses 功能测试" do
    test "冒号加空白加表格标记" do
      # 测试 :  {|
      lexer = Lexer.new(":  {|")

      # 第一个 token: 开启 dl
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == ":"
      assert token1.tag == "dl"

      # 第二个 token: 开启 dd
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == ":"
      assert token2.tag == "dd"

      # 第三个 token: 空格
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :space
      assert token3.raw == "  "

      # 第四个 token: 开启 table
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :open
      assert token4.raw == "{|"
      assert token4.tag == "table"
    end

    test "冒号加HTML注释加表格标记" do
      # 测试 :<!-- comment -->{|
      lexer = Lexer.new(":<!-- comment -->{|")

      # 第一个 token: 开启 dl
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == ":"
      assert token1.tag == "dl"

      # 第二个 token: 开启 dd
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == ":"
      assert token2.tag == "dd"

      # 第三个 token: HTML注释
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :html_comment
      assert token3.raw == "<!-- comment -->"

      # 第四个 token: 开启 table
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :open
      assert token4.raw == "{|"
      assert token4.tag == "table"
    end
  end

  describe "list_marker_rule 边界情况测试" do
    test "非行首的列表标记不匹配" do
      # 测试 text*item (不在行首)
      lexer = Lexer.new("text*item")

      # 应该作为普通文本处理
      {token1, _lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "text*item"
    end

    test "列表标记后跟换行" do
      # 测试 "*\n"
      lexer = Lexer.new("*\n")

      {tokens, _} = Lexer.collect_all_tokens(lexer)

      assert_token_at(tokens, 0, type: :open, tag: "ul")
      assert_token_at(tokens, 4, type: :eof)
    end

    test "混合标记的复杂列表" do
      # 测试 *#;:item
      lexer = Lexer.new("*#;:item")

      {tokens, _} = Lexer.collect_all_tokens(lexer)

      assert_token_at(tokens, 0, type: :open, tag: "ul")
      assert_token_at(tokens, 8, type: :text)
    end
  end
end
