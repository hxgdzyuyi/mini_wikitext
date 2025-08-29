defmodule Mix.Tasks.Llmcopy.Parser do
  @moduledoc """
  Mix task to copy parser-related files in a specific format for LLM consumption.

  ## Usage

      mix llmcopy.parser

  This will output the following files in the specified format:
  - lib/mini_wikitext/tokens/token.ex
  - lib/mini_wikitext/lexer.ex
  - lib/mini_wikitext/parser.ex
  """

  use Mix.Task

  @shortdoc "Copy parser-related files in LLM-friendly format"

  @impl Mix.Task
  def run(_args) do
    files = [
      "lib/mini_wikitext/tokens/token.ex",
      "lib/mini_wikitext/lexer.ex",
      "lib/mini_wikitext/parser.ex"
    ]

    output =
      files
      |> Enum.map(fn file ->
        case File.read(file) do
          {:ok, content} ->
            "File: #{file}\nContent:\n#{content}\n"

          {:error, reason} ->
            "Error reading #{file}: #{reason}\n"
        end
      end)
      |> Enum.join("\n")

    output =
      [
        "我正在通过 elixir 手动写一个 wikitext 的 parser，这是我的当前代码\n",
        output
      ]
      |> Enum.join("\n")

    # 使用 pbcopy 复制到剪贴板
    try do
      port = Port.open({:spawn, "pbcopy"}, [:binary])
      Port.command(port, output)
      Port.close(port)

      IO.puts("✅ 文件内容已成功复制到剪贴板！")
      IO.puts("📄 已复制 #{length(files)} 个文件的内容")
    rescue
      error ->
        IO.puts("❌ 复制到剪贴板失败: #{inspect(error)}")
        IO.puts("📋 以下是文件内容：")
        IO.puts(output)
    end
  end
end
