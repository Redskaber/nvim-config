# 依赖倒置原则实施文档

## 问题概述

在LTOS v4架构中，存在层边界违规：

- `core/compiler/ir.lua` (Layer 1) 直接依赖 `core/domain/diagnostic.lua` 和 `core/domain/cap_types.lua` (Layer 2)
- 违反了六层架构的严格单向依赖规则：`compiler`层不应依赖`domain`层

## 解决方案设计

基于依赖倒置原则(Dependency Inversion Principle)：

1. **高层模块不应依赖低层模块，两者都应依赖抽象**
2. **抽象不应依赖细节，细节应依赖抽象**

### 架构设计

```
                 Layer 1: compiler               Layer 2: domain
                 ──────────────────             ──────────────────
                 core.compiler.types             core.domain.*
                 (抽象接口)                        (具体实现)
                        │                                │
                        └────────────┬──────────────────┘
                                     │
                                     ▼
                           Layer 4: runtime
                           ──────────────────
                           runtime.types_bootstrap
                           (依赖注入配置)
```

### 实施步骤

#### 1. 创建抽象接口层 (`core/compiler/types.lua`)

- 定义 `AbstractDiagnostic` 接口和 `DiagnosticFactory`
- 定义 `AbstractCapTypes` 接口
- 提供默认存根实现（抛出错误）
- 暴露配置API供运行时层注入具体实现

#### 2. 修改违规的编译器模块 (`core/compiler/ir.lua`)

- 移除对 `core.domain.diagnostic` 的直接依赖
- 移除对 `core.domain.cap_types` 的直接依赖
- 改为使用 `core.compiler.types` 抽象接口
- 通过 `types.diag()` 和 `types.cap_types()` 访问功能

#### 3. 创建依赖注入配置 (`runtime/types_bootstrap.lua`)

- 在Layer 4（runtime层）配置抽象接口
- 从Layer 2（domain层）获取具体实现
- 注入到Layer 1（compiler层）的抽象接口中

#### 4. 集成到启动流程 (`runtime/init.lua`)

- 在 `runtime.ports_bootstrap.setup()` 之后调用 `runtime.types_bootstrap.setup()`
- 确保类型配置在编译器使用之前完成

## 代码变化

### 新增文件

1. **`lua/core/compiler/types.lua`**
   - 抽象类型接口定义
   - 依赖注入配置API
   - 向后兼容的公共API

2. **`lua/runtime/types_bootstrap.lua`**
   - 具体实现注入配置
   - 连接domain层实现到compiler层接口

### 修改文件

1. **`lua/core/compiler/ir.lua`**
   - 第24行：`local diagnostic = require("core.domain.diagnostic")` → `local types = require("core.compiler.types")`
   - 第59行：`return diagnostic.new(...)` → `return types.diag(...)`
   - 第142行：`local cap_types = require("core.domain.cap_types")` → `local cap_types = types.cap_types()`

2. **`lua/runtime/init.lua`**
   - 在端口配置后添加类型配置：`require("runtime.types_bootstrap").setup()`

## 架构优势

### 1. 严格的层边界维护

- compiler层 (L1) 不再直接依赖 domain层 (L2)
- 所有依赖都通过抽象接口进行
- 符合六层架构的设计原则

### 2. 依赖倒置原则实现

- 高层模块 (compiler) 依赖抽象 (types)
- 低层模块 (domain) 也依赖相同的抽象
- 具体实现通过依赖注入配置

### 3. 可测试性提升

- compiler层可以通过模拟的types接口进行测试
- domain层可以独立测试
- 运行时配置可以轻松替换实现

### 4. 向后兼容性

- 公共API保持不变 (`ir.diag()`, `ir.error()`)
- 现有代码无需修改
- 测试套件继续工作

## 验证结果

1. **层边界检查**: ✅ PASSED

   ```
   $ just check
   Layer boundary check: PASSED
   ```

2. **功能测试**: ✅ PASSED
   - Diagnostic创建正常工作
   - Capability类型访问正常工作
   - IR创建和操作正常工作

3. **架构一致性**: ✅ PASSED
   - 所有层边界规则得到遵守
   - 依赖方向正确 (高层→抽象←低层)
   - 运行时配置正确集成

## 设计模式总结

### 抽象工厂模式 (Abstract Factory)

- `types.lua` 定义了抽象工厂接口
- `types_bootstrap.lua` 提供具体工厂实现
- `ir.lua` 通过工厂创建对象

### 依赖注入模式 (Dependency Injection)

- 构造函数注入: `types.configure()`
- 接口注入: 通过抽象接口访问功能
- 配置集中化: 在runtime层统一配置

### 门面模式 (Facade)

- `types.lua` 提供了简化的门面API
- 隐藏了复杂的依赖注入细节
- 为compiler层提供了统一的访问点

## 扩展指南

### 添加新的抽象类型

1. 在 `core/compiler/types.lua` 中定义抽象接口
2. 在 `runtime/types_bootstrap.lua` 中配置具体实现
3. 在需要使用的地方通过 `types` 模块访问

### 替换具体实现

1. 创建新的domain层实现
2. 修改 `types_bootstrap.lua` 中的配置
3. 所有使用抽象接口的代码自动获得新实现

### 添加新的层边界规则

1. 分析层间的依赖关系
2. 识别直接依赖违规
3. 创建抽象接口解耦
4. 通过依赖注入连接

## 结论

通过实施依赖倒置原则，我们成功解决了层边界违规问题，同时：

1. **保持了架构的纯洁性** - 严格的六层架构得到维护
2. **提高了代码的可维护性** - 抽象接口使各层解耦
3. **增强了系统的灵活性** - 依赖注入使实现可替换
4. **确保了向后兼容性** - 现有API保持不变

此解决方案为LTOS架构提供了一个可扩展的依赖管理框架，可以轻松应对未来的架构演进需求。

