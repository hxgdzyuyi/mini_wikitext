# MiniWikitext

一个没有 template 实现的轻量级的 Wikitext 解析器，用 Elixir 编写。支持将 MediaWiki 格式的 Wikitext 文本解析为 AST 并渲染为 HTML。

**全部 Vibe Coding 生成，Dirty but work**

## 例子

```elixir
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
```

输出如下

```html
<p>
  《恋与深空》的成功，使女性向游戏市场重获关注。与此同时，部分玩家指出，以男性向为主的
  <wikilink title="二次元游戏">
    二次元游戏
  </wikilink>
  模式面临挑战，其症结在于角色更新频繁与老角色缺乏维护，导致玩家难以建立长期情感连结。
</p>
<p>
  相较之下，
  <wikilink title="乙女游戏">
    乙女游戏
  </wikilink>
  因其固定的男主角及持续深入的剧情，更能满足玩家在情感上的"念旧"与"陪伴"需求。有玩家认为，二次元游戏若要维系玩家群体，应更重视角色情感的培养与连结，而非盲目追求速迭代，否则将面临玩家流失的风险。
</p>
<h2>
  展会数据
</h2>
<table class="wikitable">
  <tr>
    <th>
      项目
    </th>
    <th>
      数据
    </th>
  </tr>
  <tr>
    <td>
      参展企业
    </td>
    <td>
      799家
    </td>
  </tr>
  <tr>
    <td>
      展览面积
    </td>
    <td>
      2.5万平方米
    </td>
  </tr>
  <tr>
    <td>
      观展人次
    </td>
    <td>
      超过41万
    </td>
  </tr>
</table>
<p>
  <wikilink title="Category:二次元游戏">
    Category:二次元游戏
  </wikilink>
  <wikilink title="Category:乙女游戏">
    Category:乙女游戏
  </wikilink>
  <wikilink title="Category:电子游戏">
    Category:电子游戏
  </wikilink>
  <wikilink title="Category:游戏产业">
    Category:游戏产业
  </wikilink>
</p>
```
