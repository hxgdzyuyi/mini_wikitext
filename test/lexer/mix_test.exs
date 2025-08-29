defmodule MiniWikitext.Lexer.MixTest do
  use ExUnit.Case, async: true

  alias MiniWikitext.Lexer

  describe "实例" do
    test "实例样本一" do
      input =
        """
        《恋与深空》的成功，使女性向游戏市场重获关注。与此同时，部分玩家指出，以男性向为主的[[二次元游戏]]模式面临挑战，其症结在于角色更新频繁与老角色缺乏维护，导致玩家难以建立长期情感连结。

        相较之下，[[乙女游戏]]因其固定的男主角及持续深入的剧情，更能满足玩家在情感上的“念旧”与“陪伴”需求。有玩家认为，二次元游戏若要维系玩家群体，应更重视角色情感的培养与连结，而非盲目追求速迭代，否则将面临玩家流失的风险。

        [[Category:二次元游戏]]
        [[Category:乙女游戏]]
        [[Category:电子游戏]]
        [[Category:游戏产业]]
        """

      lexer = Lexer.new(input)
      Lexer.print_tokens(lexer)
    end
  end

  describe "混合测试" do
    test "列表" do
      # 测试基本的数据格单元
      input =
        """
        #list item A1
        ##list item B1
        ##list item B2
        #:continuing list item A1
        #list item A2
        """

      lexer = Lexer.new(input)

      Lexer.print_tokens(lexer)
    end

    test "单元格内可以加粗" do
      # 测试基本的数据格单元
      input =
        """
        {|
        |Orange
        |Apple
        |-
        |Bread
        |Pie
        |}
        """

      lexer = Lexer.new(input)

      Lexer.print_tokens(lexer)
    end

    test "混合表格测试" do
      # 测试基本的数据格单元
      input =
        """
        {| class="wikitable"
        ! 奖励      !! 参与条件
        |-
        | <b class="Hello">200元</b>现金礼金 || 在助手APP发布优质作品，并@仙妹、@诛仙世界助手
        |}
        """

      lexer = Lexer.new(input)
      Lexer.print_tokens(lexer)
    end
  end
end
