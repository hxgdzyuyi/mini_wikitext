defmodule MiniWikitext.RenderTest do
  use ExUnit.Case, async: true

  describe "MiniWikitext.render/1" do
    test "渲染简单的 wikitext" do
      wikitext = """
      《恋与深空》的成功，使女性向游戏市场重获关注。与此同时，部分玩家指出，以男性向为主的[[二次元游戏]]模式面临挑战，其症结在于角色更新频繁与老角色缺乏维护，导致玩家难以建立长期情感连结。

      相较之下，[[乙女游戏]]因其固定的男主角及持续深入的剧情，更能满足玩家在情感上的"念旧"与"陪伴"需求。有玩家认为，二次元游戏若要维系玩家群体，应更重视角色情感的培养与连结，而非盲目追求速迭代，否则将面临玩家流失的风险。

      == 展会数据 ==
      {| class="wikitable"
      |-
      ! 项目 !! 数据
      |-
      | 参展企业 || 799家
      |-
      | 展览面积 || 2.5万平方米
      |-
      | 观展人次 || 超过41万
      |}

      [[Category:二次元游戏]]
      [[Category:乙女游戏]]
      [[Category:电子游戏]]
      [[Category:游戏产业]]
      """
      html = MiniWikitext.render(wikitext, pretty: true)
      
      html
      |> IO.puts
      ## 验证返回的是 HTML 字符串
      #assert is_binary(result)
      ## 验证包含 h2 标签
      #assert result =~ "<h2>"
      #assert result =~ "</h2>"
      ## 验证包含标题文本
      #assert result =~ "测试标题"
      
      ## 验证具体输出格式
      #expected = "<h2> 测试标题 </h2>"
      #assert result == expected
    end
  end
end
