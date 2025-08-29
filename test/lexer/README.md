# Lexer 测试文件

这个文件夹包含了 `MiniWikitext.Lexer` 模块的专门测试文件。

## 文件结构

- `html_comment_test.exs` - HTML 注释相关的测试用例
  - 闭合的 HTML 注释 (`<!-- ... -->`)
  - 未闭合的 HTML 注释 (`<!-- ...`)
  - 多行注释
  - 特殊字符处理
  - 嵌套样式内容

- `non_comment_test.exs` - 非注释内容的测试用例
  - 验证非注释内容不被误识别
  - 不完整的注释标记测试
  - 边界情况测试

## 运行测试

```bash
# 运行所有 lexer 测试
mix test test/lexer/

# 运行特定的测试文件
mix test test/lexer/html_comment_test.exs
mix test test/lexer/non_comment_test.exs
```

## 测试覆盖

目前的测试覆盖了 `html_comment_rule` 函数的两种主要情况：
1. 找到结束标记 `-->` 的闭合注释
2. 没有找到结束标记的未闭合注释（消耗所有剩余内容）
