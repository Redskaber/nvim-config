# nvim

## Arch

```bash
~/.config/nvim/
├── init.lua
├── lua/
│   ├── core/
│   │   ├── bootstrap.lua
│   │   ├── capability.lua
│   │   ├── env.lua
│   │   ├── icons.lua
│   │   ├── toolchain.lua
│   │   └── util.lua
│   ├── config/
│   │   ├── autocmds.lua
│   │   ├── globals.lua
│   │   ├── keymaps.lua
│   │   ├── lazy.lua
│   │   └── options.lua
│   ├── modules/
│   │   └── lang/
│   │       ├── c_cpp.lua
│   │       ├── go.lua
│   │       ├── lua_lang.lua
│   │       ├── markup.lua
│   │       ├── nix.lua
│   │       ├── python.lua
│   │       ├── rust.lua
│   │       ├── shell.lua
│   │       ├── typescript.lua
│   │       └── zig.lua
│   ├── runtime/
│   │   ├── init.lua
│   │   ├── api.lua
│   │   └── adapters/
│   │       ├── lsp.lua
│   │       ├── mason.lua
│   │       ├── treesitter.lua
│   │       ├── conform.lua
│   │       └── lint.lua
│   └── plugins/
│       ├── ai.lua
│       ├── coding.lua
│       ├── colorscheme.lua
│       ├── editor.lua
│       ├── formatting.lua
│       ├── linting.lua
│       ├── lsp.lua
│       ├── snacks.lua
│       ├── treesitter.lua
│       └── ui.lua
```


# TODO LIST

## P0 - 必须做

1. **P0-1 [高]**: 引入明确的编译型Pipeline架构
   - 实现五阶段Pipeline：collect → normalize → resolve → optimize → codegen
   - collect阶段：收集DSL声明（modules/lang）
   - normalize阶段：标准化formatter/lsp server名称
   - resolve阶段：toolchain决策（system vs mason）
   - optimize阶段：去重、合并、lazy策略
   - codegen阶段：生成lazy.nvim spec

2. **P0-2 [高]**: 将mason mapping规则外置到toolchain层
   - 创建toolchain/rules.lua和toolchain/mappings.lua
   - 统一管理lsp_to_mason和formatter_to_mason映射
   - 支持用户自定义override

3. **P0-3 [高]**: capability增加基础类型验证
   - 定义schema约束（lsp.server、formatter.name等）
   - 实现validate函数进行fail-fast校验
   - 确保adapter接收的是受约束的AST而非弱类型table

## P1 - 重要

4. **P1-1 [中]**: modules/lang改造为纯声明式无副作用
   - 改造cap.register()为return table结构
   - 实现registry.add()统一注册机制
   - 支持静态分析和可测试性

5. **P1-2 [中]**: adapter层降级为纯函数
   - 移除adapter中的semantic inference逻辑
   - 确保adapter.build(IR) → spec的纯函数特性
   - 禁止adapter访问环境变量或执行逻辑判断

6. **P1-3 [中]**: runtime.build拆分为多阶段执行
   - 实现阶段间上下文共享机制
   - 支持中间优化策略插入
   - 提供阶段调试和dump能力

## P2 - 优化

7. **P2-1 [低]**: 统一命名规范和约束
   - formatter/linter/lsp命名标准化
   - 实现工具名称规范校验
   - 建立工具名称注册表

8. **P2-2 [低]**: 增加IR调试和可视化能力
   - 实现debug dump功能打印中间表示
   - 提供IR可视化工具
   - 支持构建过程跟踪

9. **P2-3 [低]**: 实现按filetype的lazy加载
   - lang modules按需加载机制
   - filetype触发的capability注册
   - 减少启动时的资源消耗

## P3 - 进阶

10. **P3-1 [低]**: 支持多profile构建策略
    - minimal/profile构建模式
    - 环境感知（nix/non-nix）
    - backend适配（lazy/packer/rocks）

11. **P3-2 [低]**: capability支持继承机制
    - base capability定义
    - lang-specific capability扩展
    - 继承链管理和冲突解决

12. **P3-3 [低]**: 实现插件冲突检测
    - formatter vs lsp format冲突识别
    - 工具链版本兼容性检查
    - 自动冲突解决建议

## 补充建议

- **架构定位**: 明确系统定位为"语言工具链编排系统"而非简单Neovim配置
- **核心瓶颈**: 重点补全中间层语义建模（IR + pipeline）
- **扩展性**: 通过IR和pipeline设计实现指数级可扩展性提升


