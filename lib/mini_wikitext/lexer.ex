defmodule MiniWikitext.Lexer do
  @moduledoc """
  Wikitext Lexer (递归下降友好)

  公共 API（都返回 `{token, lexer}`；当到达流末尾，`token.type == :eos`）：
    * `new/2`         —— 构造
    * `lookahead/2`   —— 前看 n
    * `peek/1`        —— 前看 1
    * `next/1`        —— 取下一个（含 stash）

  https://www.mediawiki.org/wiki/Help:Formatting
  """

  alias MiniWikitext.Tokens

  defstruct str: "",
            stash: [],
            lineno: 1,
            column: 1,
            bol: true,
            stack: [],
            prev: nil,
            mode: :block

  def new(str) do
    str =
      str
      |> Kernel.to_string()
      |> strip_bom()
      |> normalize_newlines()
      |> trim_trailing_ws_keep_final_nl()

    %__MODULE__{
      str: str
    }
  end

  defp strip_bom(<<0xFEFF::utf8, rest::binary>>), do: rest
  defp strip_bom(s), do: s

  defp normalize_newlines(s), do: String.replace(s, ~r/\r\n?/, "\n")
  defp trim_trailing_ws_keep_final_nl(s), do: Regex.replace(~r/\s+$/, s, "\n")

  def next(%__MODULE__{} = lx) do
    case stashed(lx) do
      {nil, lx1} ->
        {tok, lx2} = advance(lx1)
        {tok, %{lx2 | prev: tok}}

      {tok, lx1} ->
        {tok, %{lx1 | prev: tok}}
    end
  end

  def peek(%__MODULE__{} = lx) do
    {tok, _} = next(lx)
    tok
  end

  def print_tokens(lx) do
    {tokens, _} = collect_all_tokens(lx)

    tokens =
      Enum.map(tokens, fn token ->
        case token.type do
          :open ->
            {token.tag, raw: token.raw}

          :close ->
            {"/" <> token.tag, raw: token.raw}

          token_type ->
            {token_type, raw: token.raw}
        end
      end)

    IO.inspect(tokens)
  end

  def collect_all_tokens(lx) do
    Enum.reduce_while(1..9_000, {[], lx}, fn _, {acc, cur_lx} ->
      {token, new_lx} = next(cur_lx)

      if token.type == :eof do
        {:halt, {Enum.reverse([token | acc]), new_lx}}
      else
        {:cont, {[token | acc], new_lx}}
      end
    end)
  end

  defp stashed(%__MODULE__{stash: []} = lx), do: {nil, lx}
  defp stashed(%__MODULE__{stash: [h | t]} = lx), do: {h, %{lx | stash: t}}

  def advance(%__MODULE__{} = lx) do
    col = lx.column
    line = lx.lineno

    with nil <- list_autoclose_rule(lx),
         nil <- eos_rule(lx),
         nil <- newline_rule(lx),
         nil <- html_comment_rule(lx),
         nil <- nowiki_rule(lx),
         nil <- table_fence_rule(lx),
         nil <- link_fence_rule(lx),
         nil <- bold_italic_rule(lx),
         nil <- heading_rule(lx),
         nil <- hr_rule(lx),
         nil <- table_caption_rule(lx),
         nil <- table_row_or_cell_rule(lx),
         nil <- list_marker_rule(lx),
         nil <- html_tag_rule(lx),
         nil <- space_rule(lx),
         nil <- text_rule(lx) do
      # should not happen; to be safe emit eos
      {
        Tokens.set_token_pos(Tokens.create_token(:eof), line, col),
        lx
      }
    else
      {tok, lx1} ->
        {Tokens.set_token_pos(tok, line, col), lx1}
    end
  end

  defp skip(%__MODULE__{} = lx, len) when is_integer(len) and len >= 0 do
    s = binary_part(lx.str, 0, min(len, byte_size(lx.str)))

    rest =
      if byte_size(lx.str) > len do
        binary_part(lx.str, len, byte_size(lx.str) - len)
      else
        ""
      end

    move(%{lx | str: rest}, s)
  end

  defp skip_match(lx, [full | _]), do: skip(lx, byte_size(full))
  defp skip_match(lx, full) when is_binary(full), do: skip(lx, byte_size(full))

  defp move(%__MODULE__{} = lx, s) do
    # 统计换行并更新列
    parts = String.split(s, "\n", parts: :infinity)
    nl = length(parts) - 1

    cond do
      nl == 0 ->
        %{lx | column: lx.column + String.length(s), bol: lx.column + String.length(s) == 1}

      true ->
        after_last = List.last(parts) |> String.length()
        %{lx | lineno: lx.lineno + nl, column: after_last + 1, bol: true}
    end
  end

  defp pop_if(%__MODULE__{stack: st} = lx, want) do
    case List.last(st) do
      ^want -> %{lx | stack: :lists.sublist(st, length(st) - 1)}
      _ -> lx
    end
  end

  # ===== Rules =====

  # End of stream
  defp eos_rule(%__MODULE__{str: "", mode: :inline} = lx) do
    {Tokens.create_token(:eof), lx}
  end

  defp eos_rule(%__MODULE__{str: "", mode: :block} = lx) do
    # 若还有未闭合的列表上下文，先把它们关完再发 eof
    if has_open_lists?(lx) do
      {tokens, new_stack} = close_all_list_context(lx.stack)

      case tokens do
        [] ->
          {Tokens.create_token(:eof), %{lx | stack: new_stack}}

        [first | rest] ->
          # 先返回第一个 close，其余塞进 stash；
          # stack 同步为已关闭后的状态，这样后续就会真正触发 eof
          {first, %{lx | stack: new_stack, stash: rest ++ lx.stash}}
      end
    else
      {Tokens.create_token(:eof), lx}
    end
  end

  defp eos_rule(_), do: nil

  # Newline
  defp newline_rule(%__MODULE__{str: <<?\n, _::binary>>} = lx) do
    lx1 = skip(lx, 1)
    {Tokens.create_token(:newline, "\n"), %{lx1 | bol: true}}
  end

  defp newline_rule(_), do: nil

  # HTML comment <!-- ... -->
  defp html_comment_rule(%__MODULE__{str: str} = lx) do
    if String.starts_with?(str, "<!--") do
      case :binary.match(str, "-->") do
        {idx, 3} ->
          raw = binary_part(str, 0, idx + 3)
          lx1 = skip(lx, byte_size(raw))
          {Tokens.create_token(:html_comment, raw), lx1}

        :nomatch ->
          # 整个余下都是注释（未闭合）
          raw = str
          lx1 = skip(lx, byte_size(raw))
          {Tokens.create_token(:html_comment, raw), lx1}
      end
    else
      nil
    end
  end

  # ===== [[wikilink]] =====
  # 与 Parsoid PEGPHP 的 wikilink / broken_wikilink 对齐：
  # - 只有看到配对的 "]]" 才尝试完整解析；
  # - "broken_wikilink"：形如 "[[[", "[[http...]" 等，仅消费一个 '[' 返回 text；
  # - pipe trick：[[Target|]] => 还原为纯文本 token 列表，而非 wikilink token；
  defp link_fence_rule(%__MODULE__{str: str} = lx) do
    if String.starts_with?(str, "[[") do
      # 先处理 broken_wikilink：紧跟的是 "[" 或典型的外链开头（http/https/ftp/mailto/news 或 "//"）
      <<_::binary-size(2), after_str::binary>> = str

      cond do
        String.starts_with?(after_str, "[") or starts_with_extlink?(after_str) ->
          # 仅消费一个 '['（与 PEG 中 broken_wikilink 的语义一致）
          lx1 = skip(lx, 1)
          {Tokens.create_token(:text, "["), lx1}

        true ->
          # 寻找配对的 "]]"
          case :binary.match(str, "]]") do
            :nomatch ->
              # 没有闭合，按 broken 处理：消费一个 '['
              lx1 = skip(lx, 1)
              {Tokens.create_token(:text, "["), lx1}

            {close_idx, 2} ->
              # inside = 介于 "[[" 与 "]]" 之间的原文
              inside =
                if close_idx >= 2,
                  do: binary_part(str, 2, close_idx - 2),
                  else: ""

              {target, contents, first_pipe_src} = parse_wikilink_inside(inside)

              pipe_trick =
                length(contents) == 1 and blank_or_comment?(hd(contents))

              if String.trim(target) == "" or pipe_trick do
                # 还原为文本序列：'[[', target, '|'（保留 first_pipe_src），每个内容段（此处空），']]'
                parts = build_pipe_trick_text_parts(target, contents, first_pipe_src)
                # 吃掉到 ']]'（含）
                total = close_idx + 2
                lx1 = skip(lx, total)
                emit_parts_as_text(parts, lx1)
              else
                # 产出自闭合 wikilink token
                attrs = %{
                  href: String.trim(target),
                  # 若你希望更贴近 PEG，可把下行改为：Enum.map(contents, &lex_inline(&1, lx))
                  contents: Enum.map(contents, &String.trim/1),
                  firstPipeSrc: first_pipe_src
                }

                raw = binary_part(str, 0, close_idx + 2)
                lx1 = skip(lx, close_idx + 2)
                {Tokens.create_token(:self_closing, raw, "wikilink", attrs), lx1}
              end
          end
      end
    else
      nil
    end
  end

  # ===== Lists (ul/ol/dl & li/dt/dd) =====
  # 语义对齐 Parsoid 的 block_line / li / dtdd / hacky_dl_uses：
  # - 行首 [*#:;]+ 触发
  # - 最末 bullet 决定行内项类型：*或# => <li>；; => <dt>；: => <dd>
  # - dtdd: “; term : def : def2 ...” 在一行里产出 <dt>term</dt><dd>def</dd><dd>def2</dd>...
  # - hacky_dl_uses: ":" + (空白/注释)* + "{|" 视作缩进项里紧随表格的特殊用法
  # ===== Auto close lists at BOL when the next line is not a list marker =====
  defp list_autoclose_rule(%__MODULE__{bol: true, mode: :block} = lx) do
    if has_open_lists?(lx) and not next_line_is_list_marker?(lx.str) do
      {tokens, new_stack} = close_all_list_context(lx.stack)

      case tokens do
        [] ->
          nil

        [first | rest] ->
          {first, %{lx | stash: rest ++ lx.stash, stack: new_stack}}
      end
    else
      nil
    end

    nil
  end

  defp list_autoclose_rule(_), do: nil

  defp list_marker_rule(%__MODULE__{bol: true, str: str} = lx) do
    # 捕获行首 bullets 与该行余下内容（不含换行）
    case Regex.run(~r/^([*#:;]+)(.*?)(?=\n|\z)/u, str) do
      nil ->
        nil

      [full, bullets_src, rest_line] ->
        bullets = String.codepoints(bullets_src)
        desired_conts = Enum.map(bullets, &bullet_to_container/1)

        # 当前 stack 中的已打开列表容器（仅 ul/ol/dl，保持顺序）
        cur_conts = current_list_containers(lx.stack)
        _cur_depth = length(cur_conts)
        _des_depth = length(desired_conts)
        lcp = common_prefix_len(cur_conts, desired_conts)

        # 构建要输出的 token 序列；同时模拟更新 stack
        {tokens, new_stack} =
          build_list_open_sequence(lx.stack, cur_conts, desired_conts, bullets, lcp)

        last_b = List.last(bullets)

        # —— hacky_dl_uses：":" + (空白/注释)* + "{|"
        # 仅当所有 bullets 都是 ":" 且 rest_line 符合
        cond do
          Enum.all?(bullets, &(&1 == ":")) and
              Regex.match?(~r/^(?:[ \t]+|<!--.*?-->)*\{\|/u, rest_line) ->
            # 拆出 bullets 后紧随的 空白/注释 片段
            [sc_part] =
              case Regex.run(~r/^((?:[ \t]+|<!--.*?-->)*)/u, rest_line, capture: :all_but_first) do
                nil -> [""]
                xs -> xs
              end

            sc_tokens = heading_trailing_spc_tokens(sc_part)

            # 解析 "{|" 及其后属性
            tbl_after =
              binary_part(
                rest_line,
                byte_size(sc_part),
                byte_size(rest_line) - byte_size(sc_part)
              )

            # tbl_after 形如 "{|" + attrs_src(到行尾/注释前)
            attrs_src =
              if byte_size(tbl_after) >= 2 do
                binary_part(tbl_after, 2, byte_size(tbl_after) - 2)
                |> cut_before_comment()
                |> String.trim_trailing()
              else
                ""
              end

            attrs = parse_table_attrs(attrs_src)

            open_dd = Tokens.create_token(:open, ":", "dd", %{})
            open_tbl = Tokens.create_token(:open, "{|", "table", attrs)

            tokens2 = tokens ++ [open_dd] ++ sc_tokens ++ [open_tbl]
            new_stack2 = new_stack ++ ["dd", "{|"]

            # 消费整行（不吃换行），随后吃掉可选换行
            lx1 = lx |> skip(byte_size(full)) |> skip_optional_newline()

            {first, rest} =
              case tokens2 do
                [t | ts] -> {t, ts}
                _ -> {Tokens.create_token(:text, ""), []}
              end

            {first, %{lx1 | stash: rest ++ lx1.stash, stack: new_stack2}}

          # —— dtdd：“; term : def : def2 ...” —— 一行内产出多个项
          last_b == ";" ->
            segs = split_on_unquoted(rest_line, ":")
            {tokens2, new_stack2} = build_dtdd_tokens(tokens, new_stack, segs)

            lx1 = lx |> skip(byte_size(full)) |> skip_optional_newline()

            {first, rest} =
              case tokens2 do
                [t | ts] -> {t, ts}
                _ -> {Tokens.create_token(:text, ""), []}
              end

            {first, %{lx1 | stash: rest ++ lx1.stash, stack: new_stack2}}

          # —— 普通 li / dd：开项 + 行内内容，然后**在本行就闭合该项**
          true ->
            item_tag =
              case last_b do
                "*" -> "li"
                "#" -> "li"
                ":" -> "dd"
                _ -> "li"
              end

            open_item = Tokens.create_token(:open, last_b, item_tag, %{})

            inner_tokens =
              case String.trim(rest_line) do
                "" -> []
                inner -> lex_inline(inner, lx)
              end

            close_item = Tokens.create_token(:close, "", item_tag, %{})

            tokens2 = tokens ++ [open_item] ++ inner_tokens ++ [close_item]
            # 注意：本行闭合项，不把 item_tag 留在 stack 里
            new_stack2 = new_stack

            lx1 = lx |> skip(byte_size(full)) |> skip_optional_newline()

            {first, rest} =
              case tokens2 do
                [t | ts] -> {t, ts}
                _ -> {Tokens.create_token(:text, ""), []}
              end

            {first, %{lx1 | stash: rest ++ lx1.stash, stack: new_stack2}}
        end
    end
  end

  defp list_marker_rule(_), do: nil

  # ===== HTML/XML-like tags =====
  defp html_tag_rule(%__MODULE__{str: str} = lx) do
    # 快速排除（注释/nowiki 已由更早规则处理）
    if not String.starts_with?(str, "<") or String.starts_with?(str, "<!--") do
      nil
    else
      # "<" ["/"?] tag_name
      case Regex.run(~r/^<(?:(\/)?([^\t\n\v \/>\0]+))/u, str) do
        nil ->
          nil

        [head, end_slash, name] ->
          pos0 = byte_size(head)
          lc_name = String.downcase(name)

          {ok?, pos_end, attrs, selfclose?} =
            parse_html_attrs_and_close(str, pos0, %{})

          if not ok? do
            nil
          else
            raw = binary_part(str, 0, pos_end)
            lx1 = skip(lx, pos_end)

            # 特例：支持 </br> == <br/>
            is_closing_tag = end_slash != nil and end_slash != ""
            special_close_br = is_closing_tag and lc_name == "br"

            cond do
              special_close_br ->
                {
                  Tokens.create_token(:self_closing, raw, lc_name, attrs),
                  lx1
                }

              is_closing_tag ->
                {
                  Tokens.create_token(:close, raw, lc_name, %{}),
                  lx1
                }

              selfclose? ->
                {
                  Tokens.create_token(:self_closing, raw, lc_name, attrs),
                  lx1
                }

              true ->
                {
                  Tokens.create_token(:open, raw, lc_name, attrs),
                  lx1
                }
            end
          end
      end
    end
  end

  # ===== Bold / Italic quotes: '' ''' ''''' =====
  defp bold_italic_rule(%__MODULE__{str: str} = lx) do
    case Regex.run(~r/^'{2,}/u, str) do
      nil ->
        nil

      [full] ->
        n = String.length(full)

        # Parsoid 的 plainticks 规则
        plainticks =
          cond do
            n == 4 -> 1
            n > 5 -> n - 5
            true -> 0
          end

        control_len = n - plainticks
        # 只有 0 / 2 / 3 / 5；0 表示整段都是普通 '
        control_len =
          case control_len do
            2 -> 2
            3 -> 3
            5 -> 5
            _ -> 0
          end

        # 根据当前是否处于 i / b 中，生成将要输出的 token 列表（可能为 0、1 或 2 个）
        {tokens, ops} =
          build_quote_tokens_and_ops(lx, control_len)

        # 消费整段引号
        lx1 = skip(lx, n)

        # 应用这些 token 对 stack 的影响（见下方 apply_fmt_ops_to_stack/2）
        new_stack = apply_fmt_ops_to_stack(lx1.stack, ops)

        # 若有 plainticks，先返回它作为普通文本，再把格式 token 丢进 stash
        if plainticks > 0 do
          plain = String.duplicate("'", plainticks)

          {
            Tokens.create_token(:text, plain),
            %{lx1 | stash: tokens ++ lx1.stash, stack: new_stack}
          }
        else
          # 没有 plainticks：直接返回第一个格式 token，剩余的进 stash
          case tokens do
            [] ->
              # 没有任何控制含义（理论上只有 control_len=0 会到这里）
              {Tokens.create_token(:text, full), lx1}

            [t] ->
              {t, %{lx1 | stack: new_stack}}

            [t1, t2] ->
              {t1, %{lx1 | stash: [t2 | lx1.stash], stack: new_stack}}
          end
        end
    end
  end

  # ===== Headings =====
  # 行首的 ==...== 标题；不消耗行尾换行
  # has_ce - 是否有闭合
  # spc - 行尾空白 / 注释
  defp heading_rule(%__MODULE__{bol: true, str: str} = lx) do
    # ^(=+)(?:(.*?)(=+))?((?:[ \t]+|<!--.*?-->)*)(?=\n|\z)
    #  1:s         2:c   3:e       4:spc
    re = ~r/^(=+)(?:(.*?)(=+))?((?:[ \t]+|<!--.*?-->)*)(?=\n|\z)/u

    case Regex.run(re, str) do
      nil ->
        nil

      [full, s, c, e, spc] ->
        s_len = String.length(s)
        has_ce = not is_nil(e)

        # guard：要么有闭合等号，要么左侧等号数 > 2
        if not has_ce and s_len <= 2 do
          nil
        else
          {level, inner0, extras1, extras2} =
            if has_ce do
              e_len = String.length(e)
              level = min(s_len, e_len)

              # 层级最大 6
              level = min(level, 6)

              # 冗余等号并入内容
              ex1 = if s_len > level, do: String.slice(s, 0, s_len - level), else: ""
              ex2 = if e_len > level, do: String.slice(e, 0, e_len - level), else: ""

              {level, c || "", ex1, ex2}
            else
              # 无闭合等号：floor((n-1)/2)；中间至少 1 个字符
              level = div(s_len - 1, 2)
              mid = String.duplicate("=", s_len - 2 * level)
              {level, mid, "", ""}
            end

          # 生成开闭标记（值用 level 个 '='，方便还原源位置长度）
          mark = String.duplicate("=", level)

          open =
            Tokens.create_token(:open, mark, "h#{level}", %{})

          close =
            Tokens.create_token(:close, mark, "h#{level}", %{})

          # 内容 = extras1 ++ inner0 ++ extras2
          inner = extras1 <> inner0 <> extras2

          # 行尾空白 / 注释拆成 token（出现在 </hN> 之后）
          spc_tokens = heading_trailing_spc_tokens(spc)

          # 跳过除换行外的整段
          lx1 = skip_match(lx, full)

          {
            open,
            %{lx1 | stash: [Tokens.create_token(:text, inner), close] ++ spc_tokens ++ lx1.stash}
          }
        end
    end
  end

  defp heading_rule(_), do: nil

  # <nowiki>...</nowiki>
  defp nowiki_rule(%__MODULE__{str: str} = lx) do
    if String.starts_with?(str, "<nowiki>") do
      case :binary.match(str, "</nowiki>") do
        :nomatch ->
          lx1 = skip(lx, byte_size("<nowiki>"))

          {
            Tokens.create_token(:open, "<nowiki>", "nowiki", %{}),
            lx1
          }

        {idx, _len} ->
          raw = binary_part(str, 0, idx + byte_size("</nowiki>"))

          # 依次压入 close 与 inner，让 open 先返回
          lx1 = skip(lx, byte_size("<nowiki>"))

          open =
            Tokens.create_token(:open, "<nowiki>", "nowiki", %{})

          inner =
            raw
            |> binary_part(
              byte_size("<nowiki>"),
              byte_size(raw) - byte_size("<nowiki>") - byte_size("</nowiki>")
            )

          close =
            Tokens.create_token(:open, "</nowiki>", "nowiki", %{})

          {
            %{open | lineno: lx1.lineno, column: lx1.column},
            %{lx1 | stash: [Tokens.create_token(:text, inner), close | lx1.stash]}
          }
      end
    else
      nil
    end
  end

  # Text chunk (until any special control)
  defp text_rule(%__MODULE__{str: ""} = lx), do: {Tokens.create_token(:eof), lx}

  defp text_rule(%__MODULE__{str: str} = lx) do
    case Regex.run(~r/^[^\n<\[\]\{\}\|!'=]+/u, str) do
      nil ->
        # 单个落单字符：以 text 返回避免死循环
        <<ch::utf8, _::binary>> = str
        lx1 = skip(lx, byte_size(<<ch::utf8>>))
        {Tokens.create_token(:text, <<ch::utf8>>), lx1}

      [full] ->
        lx1 = skip_match(lx, full)
        {Tokens.create_token(:text, full), lx1}
    end
  end

  # Spaces (optionally emitted)
  defp space_rule(%__MODULE__{str: str} = lx) do
    case Regex.run(~r/^[ \t]+/u, str) do
      nil ->
        nil

      m ->
        lx1 = skip_match(lx, m)

        {Tokens.create_token(:space, hd(m)), lx1}
    end
  end

  # Horizontal rule at BOL: ----
  defp hr_rule(%__MODULE__{bol: true, str: str} = lx) do
    case Regex.run(~r/^(?:-{4,})(?=\s*$|\s)/u, str) do
      nil ->
        nil

      [full | _] ->
        lx1 = skip_match(lx, full)
        {Tokens.create_token(:self_closing, full, "hr", nil), lx1}
    end
  end

  defp hr_rule(_), do: nil

  # {|  |}
  defp table_fence_rule(%__MODULE__{bol: true, str: str, stack: st} = lx) do
    cond do
      # 开始标签：行首 "{|"
      String.starts_with?(str, "{|") ->
        # 取当前行（不含换行符）
        {line, line_len} = take_line(str)
        # 去掉 "{|" 前缀，拿到余下部分
        rest = if byte_size(line) >= 2, do: binary_part(line, 2, byte_size(line) - 2), else: ""
        # 按 Parsoid 思路：属性只取到注释（若有）之前；并去掉尾随空白
        attrs_src =
          rest
          |> cut_before_comment()
          |> String.trim_trailing()

        attrs = parse_table_attrs(attrs_src)

        # —— 新增：把 attrs 之后、换行之前的 “行尾空白/注释” 拆成 token
        # 本行 "{|" + attrs_src 之后的剩余（仅可能是空白或 <!-- -->）
        trailing_after_attrs =
          if byte_size(rest) > byte_size(attrs_src) do
            binary_part(rest, byte_size(attrs_src), byte_size(rest) - byte_size(attrs_src))
          else
            ""
          end

        spc_tokens = heading_trailing_spc_tokens(trailing_after_attrs)

        lx1 = skip(lx, line_len)

        {lx2, _ate_nl} =
          case lx1.str do
            <<?\n, _::binary>> ->
              {lx1 |> Map.put(:bol, true), true}

            _ ->
              {lx1, false}
          end

        {
          Tokens.create_token(:open, "{|", "table", attrs),
          %{lx2 | stack: st ++ ["{|"], stash: spc_tokens ++ lx2.stash}
        }

      # 结束标签：行首 "|}"
      String.starts_with?(str, "|}") ->
        close_table = Tokens.create_token(:close, "|}", "table", %{})

        {tokens, lx} =
          if in_row?(lx) do
            # 先关闭当前行
            close_tr = Tokens.create_token(:close, "", "tr", %{})
            {[close_tr], pop_if(lx, "tr")}
          else
            {[], lx}
          end

        final_stack = tokens ++ [close_table]
        lx = pop_if(lx, "{|")

        case final_stack do
          [] ->
            nil

          [first | rest] ->
            lx = skip(lx, 2)
            {first, %{lx | stash: rest ++ lx.stash, stack: lx.stack}}
        end

      true ->
        nil
    end
  end

  defp table_fence_rule(_), do: nil

  # |+ 表格标题（caption）
  defp table_caption_rule(%__MODULE__{str: str} = lx) do
    # 需要在表格里
    if in_table?(lx) and String.starts_with?(str, "|+") do
      {line, line_len} = take_line(str)
      rest = if byte_size(line) >= 2, do: binary_part(line, 2, byte_size(line) - 2), else: ""

      # row_syntax_table_args: attrs | content  （注意只认单个 |）
      {attrs, content} =
        case find_single_pipe_separator(rest) do
          nil ->
            # 无参数，整段是内容
            {%{}, String.trim_leading(rest)}

          idx ->
            attrs_src = rest |> binary_part(0, idx) |> cut_before_comment() |> String.trim()
            inner = binary_part(rest, idx + 1, byte_size(rest) - idx - 1)
            {parse_table_attrs(attrs_src), inner}
        end

      # 消费整行（不吃换行）
      lx1 = skip(lx, line_len)

      open =
        Tokens.create_token(
          :open,
          "|+",
          "table_caption",
          attrs
        )

      close =
        Tokens.create_token(:close, "", "table_caption", %{})

      stash_tail =
        case content do
          "" -> [close | lx1.stash]
          _ -> [Tokens.create_token(:text, content), close | lx1.stash]
        end

      {open, %{lx1 | stash: stash_tail}}
    else
      nil
    end
  end

  defp table_caption_rule(_), do: nil

  # 行或单元格：|-  |...  !...
  defp table_row_or_cell_rule(%__MODULE__{bol: bol, str: str} = lx) do
    if in_table?(lx) do
      cond do
        # 行开始：|-
        String.starts_with?(str, "|-") and bol === true ->
          {line, line_len} = take_line(str)
          rest = if byte_size(line) >= 2, do: binary_part(line, 2, byte_size(line) - 2), else: ""
          attrs_src = rest |> cut_before_comment() |> String.trim()
          attrs = parse_table_attrs(attrs_src)
          lx1 = lx |> skip(line_len) |> skip_optional_newline()

          open_tr =
            Tokens.create_token(:open, "|-", "tr", attrs)

          if in_row?(lx) do
            # 先关闭上一行，把新行 open 放入 stash；stack 最终应为“已开新行”
            close_tr = Tokens.create_token(:close, "", "tr", %{})

            {
              newline_token(),
              lx1
              |> pop_if("tr")
              |> push_stack("tr")
              |> prepend_stash(open_tr)
              |> prepend_stash(close_tr)
            }
          else
            {open_tr, lx1 |> push_stack("tr")}
          end

        # 数据格行：以 | 开头
        String.starts_with?(str, "|") and bol === true ->
          {line, line_len} = take_line(str)

          after_marker =
            if byte_size(line) >= 1, do: binary_part(line, 1, byte_size(line) - 1), else: ""

          cell_tokens = build_cell_tokens_with_closers(:td, "|", "||", after_marker, lx)

          {tokens, final_stack} =
            if in_row?(lx) do
              {
                [newline_token() | cell_tokens],
                lx.stack
              }
            else
              open_tr =
                Tokens.create_token(:open, "", "tr", %{})

              {
                [open_tr | cell_tokens],
                # 隐式开行后又在本行末关闭，最终不留 "tr"
                lx.stack ++ ["tr"]
              }
            end

          case tokens do
            [] ->
              nil

            [first | rest] ->
              lx1 = skip(lx, line_len)
              lx1 = skip_optional_newline(lx1)

              {first, %{lx1 | stash: rest ++ lx1.stash, stack: final_stack}}
          end

        # 表头格行：以 ! 开头
        String.starts_with?(str, "!") ->
          {line, line_len} = take_line(str)

          after_marker =
            if byte_size(line) >= 1, do: binary_part(line, 1, byte_size(line) - 1), else: ""

          cell_tokens = build_cell_tokens_with_closers(:th, "!", "!!", after_marker, lx)

          {tokens, final_stack} =
            if in_row?(lx) do
              {cell_tokens ++
                 [Tokens.create_token(:close, "", "tr", %{})], List.delete(lx.stack, "tr")}
            else
              open_tr =
                Tokens.create_token(:open, "", "tr", %{})

              {[open_tr | cell_tokens] ++
                 [Tokens.create_token(:close, "", "tr", %{})], lx.stack}
            end

          case tokens do
            [] ->
              nil

            [first | rest] ->
              lx1 = skip(lx, line_len)
              lx1 = skip_optional_newline(lx1)
              {first, %{lx1 | stash: rest ++ lx1.stash, stack: final_stack}}
          end

        true ->
          nil
      end
    else
      nil
    end
  end

  defp table_row_or_cell_rule(_), do: nil

  # ===== Helpers =====
  defp in_table?(%__MODULE__{stack: st}), do: Enum.member?(st, "{|")

  # NEW: 行状态
  defp in_row?(%__MODULE__{stack: st}), do: Enum.member?(st, "tr")

  # 取到本行（不含换行符）的二进制切片与其字节长度
  defp take_line(src) do
    case :binary.match(src, "\n") do
      {idx, 1} -> {binary_part(src, 0, idx), idx}
      :nomatch -> {src, byte_size(src)}
    end
  end

  # 截断在首个 HTML 注释开始处（不包含注释本身）
  defp cut_before_comment(line) do
    case :binary.match(line, "<!--") do
      {idx, _} -> binary_part(line, 0, idx)
      :nomatch -> line
    end
  end

  # 二进制上判断给定位置是否匹配 sep
  defp match_at?(bin, sep, i) do
    byte_size(bin) - i >= byte_size(sep) and
      :binary.part(bin, {i, byte_size(sep)}) == sep
  end

  # 在未被引号包裹的上下文中，按 sep 分割
  defp split_on_unquoted(bin, sep) do
    do_split_on_unquoted(bin, sep, false, false, [], 0, 0)
  end

  defp do_split_on_unquoted(bin, _sep, _in_s, _in_d, acc, last_start, i)
       when i >= byte_size(bin) do
    seg =
      binary_part(bin, 0, byte_size(bin))
      |> binary_part(last_start, byte_size(bin) - last_start)

    Enum.reverse([seg | acc])
  end

  defp do_split_on_unquoted(bin, sep, in_s, in_d, acc, last_start, i) do
    cond do
      not in_s and not in_d and match_at?(bin, sep, i) ->
        seg = binary_part(bin, last_start, i - last_start)

        do_split_on_unquoted(
          bin,
          sep,
          in_s,
          in_d,
          [seg | acc],
          i + byte_size(sep),
          i + byte_size(sep)
        )

      true ->
        <<_::binary-size(i), ch::utf8, _::binary>> = bin

        {in_s2, in_d2} =
          case ch do
            ?' when not in_d -> {not in_s, in_d}
            ?" when not in_s -> {in_s, not in_d}
            _ -> {in_s, in_d}
          end

        do_split_on_unquoted(bin, sep, in_s2, in_d2, acc, last_start, i + byte_size(<<ch::utf8>>))
    end
  end

  # 找到未被引号包裹的“单个竖线”分隔符（不是 ||）
  defp find_single_pipe_separator(seg) do
    do_find_single_pipe(seg, 0, false, false)
  end

  defp do_find_single_pipe(seg, i, _in_s, _in_d) when i >= byte_size(seg), do: nil

  defp do_find_single_pipe(seg, i, in_s, in_d) do
    cond do
      not in_s and not in_d and match_at?(seg, "|", i) ->
        prev_pipe = i > 0 and :binary.at(seg, i - 1) == ?|
        next_pipe = i + 1 < byte_size(seg) and :binary.at(seg, i + 1) == ?|

        if not prev_pipe and not next_pipe do
          i
        else
          do_find_single_pipe(seg, i + 1, in_s, in_d)
        end

      true ->
        <<_::binary-size(i), ch::utf8, _::binary>> = seg

        {in_s2, in_d2} =
          case ch do
            ?' when not in_d -> {not in_s, in_d}
            ?" when not in_s -> {in_s, not in_d}
            _ -> {in_s, in_d}
          end

        do_find_single_pipe(seg, i + byte_size(<<ch::utf8>>), in_s2, in_d2)
    end
  end

  # 把一个 cell 段落解析成 {attrs, inner_text}
  defp parse_cell_segment(seg) do
    s1 = String.trim_leading(seg)

    case find_single_pipe_separator(s1) do
      nil ->
        {%{}, s1}

      idx ->
        attrs_src = s1 |> binary_part(0, idx) |> cut_before_comment() |> String.trim()
        inner = binary_part(s1, idx + 1, byte_size(s1) - idx - 1)
        {parse_table_attrs(attrs_src), inner}
    end
  end

  # NEW: 为单元格补齐 close（open [+ text] + close）
  defp build_cell_tokens_with_closers(kind, first_marker, sep, line_after_marker, lx)
       when kind in [:td, :th] do
    tag_name = if(kind == :td, do: "td", else: "th")
    segs = split_on_unquoted(line_after_marker, sep)

    Enum.with_index(segs)
    |> Enum.flat_map(fn {seg, idx} ->
      marker = if idx == 0, do: first_marker, else: sep
      {attrs, inner} = parse_cell_segment(seg)

      open =
        Tokens.create_token(
          :open,
          marker,
          tag_name,
          attrs
        )

      close = Tokens.create_token(:close, "", tag_name, %{})

      inner_tokens =
        case inner do
          "" -> []
          _ -> lex_inline(String.trim(inner), lx)
        end

      [open | inner_tokens] ++ [close]
    end)
  end

  # 解析 { | 后紧随的一段属性字串为 KV map。
  # 支持 key[=value]；value 可为 "双引号" / '单引号' / 非引号的连续非空白。
  defp parse_table_attrs(attrs_src) when is_binary(attrs_src) do
    s = attrs_src |> String.trim_leading() |> String.trim_trailing()

    if s == "" do
      %{}
    else
      # 键名允许常见的 HTML/Wikitext 写法：字母数字、_ - : .
      # 注意：未做实体解码；保留源文本。
      reg = ~r/([A-Za-z_][A-Za-z0-9_\-:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"']+)))?/u

      Regex.scan(reg, s, capture: :all_but_first)
      |> Enum.reduce(%{}, fn [key | vs], acc ->
        val = Enum.find(vs, &(&1 not in [nil, ""])) || true

        val =
          if !Enum.empty?(vs) && Enum.all?(vs, &(&1 == "")) do
            ""
          else
            val
          end

        Map.put(acc, String.to_atom(key), val)
      end)
    end
  end

  # 把行尾空白与 HTML 注释拆为 token 序列
  defp heading_trailing_spc_tokens(spc) when is_binary(spc) do
    do_spc_tokens(spc, [])
  end

  defp do_spc_tokens("", acc), do: Enum.reverse(acc)

  defp do_spc_tokens(spc, acc) do
    cond do
      m = Regex.run(~r/^[ \t]+/u, spc) ->
        seg = hd(m)
        rest = binary_part(spc, byte_size(seg), byte_size(spc) - byte_size(seg))
        tok = Tokens.create_token(:space, seg)
        do_spc_tokens(rest, [tok | acc])

      String.starts_with?(spc, "<!--") ->
        case :binary.match(spc, "-->") do
          {idx, 3} ->
            len = idx + 3
            raw = binary_part(spc, 0, len)
            rest = binary_part(spc, len, byte_size(spc) - len)
            tok = Tokens.create_token(:html_comment, raw)
            do_spc_tokens(rest, [tok | acc])

          :nomatch ->
            # 未闭合就把剩余都当作注释吞掉
            tok = Tokens.create_token(:html_comment, spc)
            do_spc_tokens("", [tok | acc])
        end

      true ->
        # 理论不应到这；防御性返回
        Enum.reverse(acc)
    end
  end

  # 根据当前栈状态与控制长度(2/3/5)生成：
  #   - tokens：要发出的 tag_open / tag_close 列表（顺序即输出顺序）
  #   - ops：   对栈的操作（{:open, "i"/"b"} 或 {:close, "i"/"b"}）
  defp build_quote_tokens_and_ops(lx, control_len) do
    i_on = in_i?(lx)
    b_on = in_b?(lx)
    marker2 = "''"
    marker3 = "'''"
    marker5 = "'''''"

    case control_len do
      0 ->
        {[], []}

      2 ->
        if i_on do
          {[close_i()], [{:close, "i"}]}
        else
          {[open_i(marker2)], [{:open, "i"}]}
        end

      3 ->
        if b_on do
          {[close_b()], [{:close, "b"}]}
        else
          {[open_b(marker3)], [{:open, "b"}]}
        end

      5 ->
        cond do
          i_on and b_on ->
            # 关闭次序与开次序相反，这里关闭 i 再关闭 b
            {[close_i(), close_b()], [{:close, "i"}, {:close, "b"}]}

          i_on and not b_on ->
            {[open_b(marker5)], [{:open, "b"}]}

          b_on and not i_on ->
            {[open_i(marker5)], [{:open, "i"}]}

          true ->
            # 都未开：先开 b 再开 i（<b><i>...）
            {[open_b(marker5), open_i(marker5)], [{:open, "b"}, {:open, "i"}]}
        end
    end
  end

  # 在“轻栈”里判断是否处于 i / b（使用你现有的 stack）
  defp in_i?(%__MODULE__{stack: st}), do: Enum.member?(st, "i")
  defp in_b?(%__MODULE__{stack: st}), do: Enum.member?(st, "b")

  # 将一组 open/close 操作作用到 stack（保持与 token 输出顺序一致）
  defp apply_fmt_ops_to_stack(st, ops) do
    Enum.reduce(ops, st, fn
      {:open, "i"}, acc -> acc ++ ["i"]
      {:open, "b"}, acc -> acc ++ ["b"]
      {:close, tag}, acc -> pop_last_occurrence(acc, tag)
      _, acc -> acc
    end)
  end

  defp pop_last_occurrence(list, what) do
    {left, right} = list |> Enum.reverse() |> Enum.split_while(&(&1 != what))

    case right do
      [] -> list
      [_hit | rest_rev] -> Enum.reverse(rest_rev) ++ Enum.reverse(left)
    end
  end

  # 生成 i/b 的开闭 token
  defp open_i(src), do: Tokens.create_token(:open, src, "i", %{})
  defp open_b(src), do: Tokens.create_token(:open, src, "b", %{})
  defp close_i, do: Tokens.create_token(:close, "", "i", %{})
  defp close_b, do: Tokens.create_token(:close, "", "b", %{})

  defp lex_inline(inner, %__MODULE__{} = parent) do
    # 注意：这里不走 new/1，避免 normalize/trim 等全局预处理干扰
    sub = %__MODULE__{
      str: inner,
      stash: [],
      # 把行/列/栈带过去，列号能不能完全对齐原文无伤大雅；至少能保持 i/b 栈一致
      lineno: parent.lineno,
      column: parent.column,
      bol: false,
      stack: parent.stack,
      prev: nil,
      mode: :inline
    }

    collect_until_eos(sub, [])
  end

  defp collect_until_eos(lx, acc) do
    {tok, lx1} = next(lx)

    case tok.type do
      # 防御：子流里“不可达”的 eof
      :eof -> Enum.reverse(acc)
      _ -> collect_until_eos(lx1, [tok | acc])
    end
  end

  defp skip_optional_newline(%__MODULE__{} = lx) do
    case lx.str do
      # move/skip 会把 lineno+1, column 设为 1, 且 bol=true
      <<?\n, _::binary>> -> skip(lx, 1)
      _ -> lx
    end
  end



  # 解析属性并定位到 '>' 结束。返回 {ok?, pos_end, attrs, selfclose?}
  defp parse_html_attrs_and_close(bin, pos, attrs) do
    rem = safe_slice(bin, pos)

    cond do
      # 首先检查真正的自闭合：以 '/>' 结尾
      match = Regex.run(~r/^([ \t\v\n\/]*)\/(\s*)>/, rem) ->
        [full, _prefix, _spaces] = match
        # 检查这是否是真正的自闭合
        # 真正的自闭合：要么是 '/>' 要么是单个 '/ >'（前面没有其他斜杠）
        if String.ends_with?(full, "/>") or
             (String.ends_with?(full, "/ >") and
                not String.contains?(String.slice(full, 0..-4//1), "/")) do
          {true, pos + byte_size(full), attrs, true}
        else
          {true, pos + byte_size(full), attrs, false}
        end

      # 检查是否有无意义的斜杠序列后跟普通的 '>'
      match = Regex.run(~r/^([ \t\v\n\/]+)>/, rem) ->
        [full, _content] = match
        {true, pos + byte_size(full), attrs, false}

      # 跳过空白字符和单独的斜杠（不紧接 >）
      match = Regex.run(~r/^(?:[ \t\v\n]+|\/(?!\s*>))+/, rem) ->
        [skip] = match
        parse_html_attrs_and_close(bin, pos + byte_size(skip), attrs)

      # '>' => 普通闭合
      String.starts_with?(rem, ">") ->
        {true, pos + 1, attrs, false}

      true ->
        # 属性：name[=value]，value 支持双/单引号或未引号
        case Regex.run(
               ~r/^([^\s=\/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'\/>]+)))?/u,
               rem
             ) do
          nil ->
            {false, pos, attrs, false}

          matches ->
            [full, key | values] = matches

            val =
              case values do
                # 双引号值（包括空字符串）
                [dq] when dq != nil -> dq
                # 单引号值（包括空字符串）
                ["", sq] when sq != nil -> sq
                # 无引号值
                ["", "", uq] when uq != nil and uq != "" -> uq
                # 无引号值（备选）
                ["", "", "", uq] when uq != nil and uq != "" -> uq
                # 布尔属性（无值）
                [] -> true
                # 其他情况默认为布尔属性
                _ -> true
              end

            new_attrs = Map.put(attrs, String.to_atom(key), val)
            parse_html_attrs_and_close(bin, pos + byte_size(full), new_attrs)
        end
    end
  end

  defp safe_slice(bin, pos) when pos >= 0 and pos <= byte_size(bin),
    do: binary_part(bin, pos, byte_size(bin) - pos)

  defp push_stack(lx, tag), do: %{lx | stack: lx.stack ++ [tag]}

  defp prepend_stash(lx, tok), do: %{lx | stash: [tok | lx.stash]}

  defp newline_token(), do: Tokens.create_token(:newline, "\n")

  # 将 bullets 的容器差异变更为 token，返回 {tokens, new_stack}
  # - 如容器类型/层级变化，先关掉当前项(li/dt/dd)，再关多余容器，再开缺少容器
  defp build_list_open_sequence(stack, cur_conts, des_conts, bullets, lcp) do
    cur_depth = length(cur_conts)
    des_depth = length(des_conts)
    item_tag = last_list_item_tag(stack)

    # 注意这里用 < 而不是 <= ：同深度的下一行不应把外层 li 关掉
    need_close_item = item_tag != nil and (des_depth < cur_depth or lcp < cur_depth)

    # 1) 先关闭多余容器（由内到外），确保得到 ...</ol>... 的顺序
    to_close = Enum.drop(cur_conts, lcp) |> Enum.reverse()

    {tokens1, stack1} =
      Enum.reduce(to_close, {[], stack}, fn cont, {ts, st} ->
        {
          ts ++ [Tokens.create_token(:close, "", cont, %{})],
          pop_last_occurrence(st, cont)
        }
      end)

    # 2) 再关闭悬空项，顺序变成 ...</ol></li>（而不是 </li></ol>）
    {tokens2, stack2} =
      if need_close_item and last_list_item_tag(stack1) != nil do
        {
          tokens1 ++ [Tokens.create_token(:close, "", item_tag, %{})],
          pop_last_occurrence(stack1, item_tag)
        }
      else
        {tokens1, stack1}
      end

    # 3) 打开缺失容器；必要时在“父容器 -> 子容器”之间自动补一个桥接项（li/dt/dd）
    open_suffix = Enum.drop(des_conts, lcp)
    bullet_suffix = Enum.drop(bullets, lcp)

    Enum.zip(open_suffix, bullet_suffix)
    |> Enum.with_index()
    |> Enum.reduce({tokens2, stack2}, fn {{cont, ch}, idx}, {ts, st} ->
      # 3a) 如果这是在某个父容器下继续下钻，则先补父级的项（若尚未打开）
      {ts, st} =
        if (idx == 0 and lcp > 0 and List.last(st) == Enum.at(des_conts, lcp - 1)) or
             (idx > 0 and List.last(st) == Enum.at(open_suffix, idx - 1)) do
          parent_bullet =
            if idx == 0, do: Enum.at(bullets, lcp - 1), else: Enum.at(bullet_suffix, idx - 1)

          item = bullet_to_item_tag(parent_bullet)
          last = List.last(st)

          if item && last not in ["li", "dt", "dd"] do
            {
              ts ++ [Tokens.create_token(:open, parent_bullet, item, %{})],
              st ++ [item]
            }
          else
            {ts, st}
          end
        else
          {ts, st}
        end

      # 3b) 打开当前缺失的容器
      {
        ts ++ [Tokens.create_token(:open, ch, cont, %{})],
        st ++ [cont]
      }
    end)
  end

  # dtdd：segs = ["term", "def", "def2", ...] 生成
  #   <dt>term</dt><dd>def</dd><dd>def2</dd>...
  defp build_dtdd_tokens(acc_tokens, stack, segs) do
    term = (List.first(segs) || "") |> String.trim()
    defs = Enum.drop(segs, 1) |> Enum.map(&String.trim/1)

    toks_dt_open = Tokens.create_token(:open, ";", "dt", %{})
    toks_dt_close = Tokens.create_token(:close, "", "dt", %{})

    dt_inner =
      case term do
        "" ->
          []

        _ ->
          lex_inline(term, %__MODULE__{
            stack: stack,
            str: "",
            lineno: 0,
            column: 0,
            bol: false,
            stash: [],
            prev: nil
          })
      end

    dt_tokens = [toks_dt_open] ++ dt_inner ++ [toks_dt_close]

    dd_tokens =
      defs
      |> Enum.flat_map(fn d ->
        open = Tokens.create_token(:open, ":", "dd", %{})

        inner =
          if d == "",
            do: [],
            else:
              lex_inline(d, %__MODULE__{
                stack: stack,
                str: "",
                lineno: 0,
                column: 0,
                bol: false,
                stash: [],
                prev: nil
              })

        close = Tokens.create_token(:close, "", "dd", %{})
        [open | inner] ++ [close]
      end)

    {acc_tokens ++ dt_tokens ++ dd_tokens, stack}
  end

  # ———— 辅助：容器/项类型映射与工具 ————

  defp bullet_to_container("*"), do: "ul"
  defp bullet_to_container("#"), do: "ol"
  defp bullet_to_container(":"), do: "dl"
  defp bullet_to_container(";"), do: "dl"
  defp bullet_to_container(_), do: "ul"

  defp current_list_containers(stack) do
    Enum.filter(stack, &(&1 in ["ul", "ol", "dl"]))
  end

  defp last_list_item_tag(stack) do
    Enum.find(Enum.reverse(stack), &(&1 in ["li", "dt", "dd"]))
  end

  defp common_prefix_len(a, b) do
    max_i = min(length(a), length(b))

    {i, _} =
      Enum.reduce_while(0..(max_i - 1), {0, {a, b}}, fn idx, {_acc, {la, lb}} ->
        if Enum.at(la, idx) == Enum.at(lb, idx) do
          {:cont, {idx + 1, {la, lb}}}
        else
          {:halt, {idx, {la, lb}}}
        end
      end)

    i
  end

  defp has_open_lists?(%__MODULE__{stack: st}),
    do: Enum.any?(st, &(&1 in ["ul", "ol", "dl"]))

  # “下一行是列表起始”只在真正的行首匹配 [*#:;]+
  # 允许行首是空白/注释则视为“非列表内容”，也会触发自动收尾
  defp next_line_is_list_marker?(str) do
    # 允许行首空白/注释被越过，但你也可以选择更保守：只判断极简 ^([*#:;]+)
    Regex.match?(~r/^([*#:;]+)/u, str)
  end

  defp close_all_list_context(stack) do
    do_close_list_context([], stack)
  end

  defp do_close_list_context(tokens, stack) do
    case List.last(stack) do
      tag when tag in ["ul", "ol", "dl", "li", "dt", "dd"] ->
        tok = Tokens.create_token(:close, "", tag, %{})
        do_close_list_context(tokens ++ [tok], pop_last_occurrence(stack, tag))

      _ ->
        {tokens, stack}
    end
  end

  defp bullet_to_item_tag("*"), do: "li"
  defp bullet_to_item_tag("#"), do: "li"
  defp bullet_to_item_tag(":"), do: "dd"
  defp bullet_to_item_tag(";"), do: "dt"
  defp bullet_to_item_tag(_), do: nil

  # 拆分 "[[...]]" 内部：target 与若干以 '|' 分隔的内容段
  # 返回 {target, contents :: [binary], first_pipe_src}
  defp parse_wikilink_inside(inside) when is_binary(inside) do
    segs = split_link_by_pipes(inside)

    case segs do
      [] ->
        {"", [], nil}

      [target_only] ->
        {target_only, [], nil}

      [target | rest] ->
        {target, rest, if(rest == [], do: nil, else: "|")}
    end
  end

  # 仅由空白与 HTML 注释组成？
  defp blank_or_comment?(s) when is_binary(s) do
    Regex.match?(~r/^(?:[ \t]+|<!--.*?-->)*$/us, s)
  end

  # 生成 pipe trick 的还原序列（按 PEG：返回 text token 列表）
  defp build_pipe_trick_text_parts(target, contents, first_pipe_src) do
    pipe_src = first_pipe_src || "|"

    base = ["[["]

    base =
      if target == "" do
        base
      else
        base ++ [target]
      end

    parts =
      case contents do
        [] ->
          base ++ ["]]"]

        [c1 | _rest] ->
          # 按 PEG，这里 c1 为空或仅空白/注释；rest 理论上不会出现
          base ++ [pipe_src] ++ if(c1 == "", do: [], else: [c1]) ++ ["]]"]
      end

    parts
  end

  # 把字符串列表作为一串 text token 依次发出（首个返回，其余塞入 stash）
  defp emit_parts_as_text(parts, %__MODULE__{} = lx) do
    toks =
      parts
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Tokens.create_token(:text, &1))

    case toks do
      [] ->
        {Tokens.create_token(:text, ""), lx}

      [first | rest] ->
        {first, %{lx | stash: rest ++ lx.stash}}
    end
  end

  # 识别典型外链起始（用于 broken_wikilink 的前瞻判断）
  defp starts_with_extlink?(bin) when is_binary(bin) do
    String.starts_with?(bin, "http://") or
      String.starts_with?(bin, "https://") or
      String.starts_with?(bin, "ftp://") or
      String.starts_with?(bin, "mailto:") or
      String.starts_with?(bin, "news:") or
      String.starts_with?(bin, "//")
  end

  # 以“顶层 |”切分（忽略 HTML 注释与单双引号内的竖线）
  defp split_link_by_pipes(bin) when is_binary(bin) do
    do_split_link_by_pipes(bin, 0, 0, false, false, false, [])
    |> Enum.reverse()
  end

  defp do_split_link_by_pipes(bin, i, last_start, _in_s, _in_d, _in_cmt, acc)
       when i >= byte_size(bin) do
    seg = binary_part(bin, last_start, byte_size(bin) - last_start)
    [seg | acc]
  end

  defp do_split_link_by_pipes(bin, i, last_start, in_s, in_d, true = _in_cmt, acc) do
    # 注释结束？
    if match_at?(bin, "-->", i) do
      do_split_link_by_pipes(bin, i + 3, last_start, in_s, in_d, false, acc)
    else
      do_split_link_by_pipes(bin, i + 1, last_start, in_s, in_d, true, acc)
    end
  end

  defp do_split_link_by_pipes(bin, i, last_start, in_s, in_d, false = in_cmt, acc) do
    cond do
      match_at?(bin, "<!--", i) ->
        do_split_link_by_pipes(bin, i + 4, last_start, in_s, in_d, true, acc)

      not in_s and not in_d and match_at?(bin, "|", i) ->
        seg = binary_part(bin, last_start, i - last_start)
        do_split_link_by_pipes(bin, i + 1, i + 1, in_s, in_d, in_cmt, [seg | acc])

      true ->
        <<_::binary-size(i), ch::utf8, _::binary>> = bin

        {in_s2, in_d2} =
          case ch do
            ?' when not in_d -> {not in_s, in_d}
            ?" when not in_s -> {in_s, not in_d}
            _ -> {in_s, in_d}
          end

        do_split_link_by_pipes(
          bin,
          i + byte_size(<<ch::utf8>>),
          last_start,
          in_s2,
          in_d2,
          in_cmt,
          acc
        )
    end
  end
end
