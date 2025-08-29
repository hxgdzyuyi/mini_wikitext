defmodule MiniWikitext.Lexer.BoldItalicTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "bold_italic_rule 测试" do
    test "匹配开头连续的 2 个单引号 - 切换 italic" do
      # 测试 '' - 开启 italic
      lexer = Lexer.new("''hello''")

      # 第一个 token: 开启 italic
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "''"
      assert token1.tag == "i"
      assert token1.options == %{}

      # 第二个 token: text
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: 关闭 italic
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :close
      assert token3.raw == ""
      assert token3.tag == "i"
    end

    test "匹配开头连续的 3 个单引号 - 切换 bold" do
      # 测试 ''' - 开启 bold
      lexer = Lexer.new("'''hello'''")

      # 第一个 token: 开启 bold
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "'''"
      assert token1.tag == "b"
      assert token1.options == %{}

      # 第二个 token: text
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: 关闭 bold
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :close
      assert token3.raw == ""
      assert token3.tag == "b"
    end

    test "长度为 4 的引号 - 先输出 1 个普通 \"'\" 文本，再把剩下 3 个当作格式控制" do
      # 测试 '''' - 1个普通' + 开启bold
      lexer = Lexer.new("''''hello'''")

      # 第一个 token: 普通单引号文本
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "'"

      # 第二个 token: 开启 bold
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "'''"
      assert token2.tag == "b"

      # 第三个 token: text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "hello"

      # 第四个 token: 关闭 bold
      {token4, _lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "b"
    end

    test "长度为 6 的引号 - 先输出 1 个普通 \"'\" 文本，剩下 5 个当作格式控制" do
      # 测试 '''''' - 1个普通' + 组合开启b、i
      lexer = Lexer.new("''''''hello'''''")

      # 第一个 token: 普通单引号文本
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "'"

      # 第二个 token: 开启 bold
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "'''''"
      assert token2.tag == "b"

      # 第三个 token: 开启 italic (从 stash 中获取)
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "'''''"
      assert token3.tag == "i"

      # 第四个 token: text
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :text
      assert token4.raw == "hello"

      # 第五个 token: 关闭 italic
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :close
      assert token5.raw == ""
      assert token5.tag == "i"

      # 第六个 token: 关闭 bold
      {token6, _lexer7} = Lexer.next(lexer6)
      assert token6.type == :close
      assert token6.raw == ""
      assert token6.tag == "b"
    end

    test "长度为 7 的引号 - 先输出 2 个普通 \"'\" 文本，剩下 5 个当作格式控制" do
      # 测试 ''''''' - 2个普通' + 组合开启b、i
      lexer = Lexer.new("'''''''hello'''''")

      # 第一个 token: 2个普通单引号文本
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "''"

      # 第二个 token: 开启 bold
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "'''''"
      assert token2.tag == "b"

      # 第三个 token: 开启 italic
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "'''''"
      assert token3.tag == "i"

      # 第四个 token: text
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :text
      assert token4.raw == "hello"

      # 第五个 token: 关闭 italic
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :close
      assert token5.raw == ""
      assert token5.tag == "i"

      # 第六个 token: 关闭 bold
      {token6, _lexer7} = Lexer.next(lexer6)
      assert token6.type == :close
      assert token6.raw == ""
      assert token6.tag == "b"
    end

    test "5 个引号 - 都未开时依次开 b、开 i" do
      # 测试 ''''' - 都未开时，先开bold再开italic
      lexer = Lexer.new("'''''hello'''''")

      # 第一个 token: 开启 bold
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "'''''"
      assert token1.tag == "b"

      # 第二个 token: 开启 italic
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "'''''"
      assert token2.tag == "i"

      # 第三个 token: text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "hello"

      # 第四个 token: 关闭 italic
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "i"

      # 第五个 token: 关闭 bold
      {token5, _lexer6} = Lexer.next(lexer5)
      assert token5.type == :close
      assert token5.raw == ""
      assert token5.tag == "b"
    end

    test "5 个引号 - 仅 italic 已开时开 bold" do
      # 测试 ''hello''''' - i已开，遇到5个引号时开b
      lexer = Lexer.new("''hello'''''world'''''")

      # 第一个 token: 开启 italic
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "''"
      assert token1.tag == "i"

      # 第二个 token: text
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: 开启 bold (因为i已开)
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "'''''"
      assert token3.tag == "b"

      # 第四个 token: text
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :text
      assert token4.raw == "world"

      # 第五个 token: 关闭 italic
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :close
      assert token5.raw == ""
      assert token5.tag == "i"

      # 第六个 token: 关闭 bold
      {token6, _lexer7} = Lexer.next(lexer6)
      assert token6.type == :close
      assert token6.raw == ""
      assert token6.tag == "b"
    end

    test "5 个引号 - 仅 bold 已开时开 italic" do
      # 测试 '''hello'''''world''''' - b已开，遇到5个引号时开i
      lexer = Lexer.new("'''hello'''''world'''''")

      # 第一个 token: 开启 bold
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "'''"
      assert token1.tag == "b"

      # 第二个 token: text
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: 开启 italic (因为b已开)
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :open
      assert token3.raw == "'''''"
      assert token3.tag == "i"

      # 第四个 token: text
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :text
      assert token4.raw == "world"

      # 第五个 token: 关闭 italic
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :close
      assert token5.raw == ""
      assert token5.tag == "i"

      # 第六个 token: 关闭 bold
      {token6, _lexer7} = Lexer.next(lexer6)
      assert token6.type == :close
      assert token6.raw == ""
      assert token6.tag == "b"
    end

    test "5 个引号 - 都已开时依次关 i、关 b" do
      # 测试 '''''hello'''''world''''' - 都已开，遇到5个引号时先关i再关b
      lexer = Lexer.new("'''''hello'''''world")

      # 第一个 token: 开启 bold
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :open
      assert token1.raw == "'''''"
      assert token1.tag == "b"

      # 第二个 token: 开启 italic
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.raw == "'''''"
      assert token2.tag == "i"

      # 第三个 token: text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "hello"

      # 第四个 token: 关闭 italic
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :close
      assert token4.raw == ""
      assert token4.tag == "i"

      # 第五个 token: 关闭 bold
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :close
      assert token5.raw == ""
      assert token5.tag == "b"

      # 第六个 token: text
      {token6, _lexer7} = Lexer.next(lexer6)
      assert token6.type == :text
      assert token6.raw == "world"
    end

    test "嵌套的 bold 和 italic 标签测试" do
      # 测试复杂的嵌套情况
      lexer = Lexer.new("normal''italic'''bold+italic'''''normal")

      # normal text
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "normal"

      # 开启 italic
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :open
      assert token2.tag == "i"

      # italic text
      {token3, lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "italic"

      # 开启 bold
      {token4, lexer5} = Lexer.next(lexer4)
      assert token4.type == :open
      assert token4.tag == "b"

      # bold+italic text
      {token5, lexer6} = Lexer.next(lexer5)
      assert token5.type == :text
      assert token5.raw == "bold+italic"

      # 关闭 italic
      {token6, lexer7} = Lexer.next(lexer6)
      assert token6.type == :close
      assert token6.tag == "i"

      # 关闭 bold
      {token7, lexer8} = Lexer.next(lexer7)
      assert token7.type == :close
      assert token7.tag == "b"

      # normal text
      {token8, _lexer9} = Lexer.next(lexer8)
      assert token8.type == :text
      assert token8.raw == "normal"
    end

    test "单个引号不匹配规则" do
      # 测试单个引号不会被 bold_italic_rule 匹配
      lexer = Lexer.new("'hello'")

      # 第一个 token: 单个引号作为文本
      {token1, lexer2} = Lexer.next(lexer)
      assert token1.type == :text
      assert token1.raw == "'"

      # 第二个 token: hello
      {token2, lexer3} = Lexer.next(lexer2)
      assert token2.type == :text
      assert token2.raw == "hello"

      # 第三个 token: 单个引号作为文本
      {token3, _lexer4} = Lexer.next(lexer3)
      assert token3.type == :text
      assert token3.raw == "'"
    end
  end
end
