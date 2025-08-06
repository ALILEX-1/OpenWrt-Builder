# OpenWrt 更新检查器 GitHub Actions 工作流文档

## 工作流概述

### 主要功能
`Openwrt-update-checker.yml` 是一个自动化监控工作流，专门用于：
- **监控 ImmortalWrt 源码仓库的更新**
- **自动检测新的代码提交**
- **触发下游编译工作流**
- **维护工作流运行记录**

### 核心价值
该工作流作为整个自动化编译系统的"触发器"，确保当上游源码有更新时，能够自动启动固件编译流程，实现真正的无人值守自动化构建。

### 与编译工作流的关系
```
OpenWrt更新检查器 → 检测到更新 → 触发repository_dispatch事件 → 启动ImmortalWrt编译工作流
```

## 文件结构分析

### 1. 工作流基本信息
```yaml
name: Openwrt 更新检查器
on:
  workflow_dispatch:  # 手动触发
  schedule:
    - cron: 0 20 * * *  # 定时触发
```

**配置说明**：
- **name**: 工作流显示名称
- **workflow_dispatch**: 支持在GitHub界面手动触发
- **schedule**: 使用cron表达式设置定时任务
  - `0 20 * * *` = 每天UTC 20:00（北京时间凌晨4:00）

### 2. 任务配置
```yaml
jobs:
  check:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - repo: immortalwrt/immortalwrt
            branch: openwrt-24.10
            hash_key: immortalwrt_commitHash
            event: immortalwrt-update
```

**矩阵策略参数**：
- **repo**: 监控的GitHub仓库（immortalwrt/immortalwrt）
- **branch**: 监控的分支（openwrt-24.10）
- **hash_key**: 缓存键名，用于存储提交哈希值
- **event**: 触发事件类型，用于启动下游工作流

### 3. 权限配置
```yaml
permissions:
  actions: write    # 管理Actions权限
  contents: read    # 读取仓库内容权限
```

## 执行流程详解

### 阶段一：检查任务（check job）

#### 步骤1：获取提交哈希值
```bash
git clone -b openwrt-24.10 --single-branch --depth 1 https://github.com/immortalwrt/immortalwrt openwrt
cd openwrt
echo "immortalwrt_commitHash=$(git rev-parse HEAD)" >> $GITHUB_OUTPUT
```

**执行逻辑**：
1. 浅克隆指定分支的最新代码（仅获取最新提交）
2. 获取最新提交的完整哈希值
3. 将哈希值输出到GitHub Actions环境变量

#### 步骤2：比较提交哈希值
```yaml
uses: actions/cache@v4
with:
  path: .immortalwrt_commitHash
  key: immortalwrt_commitHash_${{ steps.getHash.outputs.immortalwrt_commitHash }}
```

**缓存机制**：
- 使用GitHub Actions缓存功能存储上次检查的哈希值
- 缓存键包含实际的哈希值，确保唯一性
- 如果缓存命中，说明没有新提交；未命中则表示有更新

#### 步骤3：保存新哈希值
```bash
# 仅在缓存未命中时执行
echo ${{ steps.getHash.outputs.immortalwrt_commitHash }} | tee .immortalwrt_commitHash
```

#### 步骤4：触发仓库调度事件
```yaml
uses: peter-evans/repository-dispatch@v3
with:
  event-type: immortalwrt-update
```

**触发机制**：
- 仅在检测到新提交时执行
- 发送 `repository_dispatch` 事件
- 事件类型为 `immortalwrt-update`
- 下游工作流通过监听此事件类型来启动编译

### 阶段二：清理任务（del_runs job）

#### 清理工作流历史记录
```yaml
uses: Mattraks/delete-workflow-runs@v2
with:
  token: ${{ github.token }}
  repository: ${{ github.repository }}
  retain_days: 1
  keep_minimum_runs: 1
```

**清理策略**：
- 保留最近1天的运行记录
- 至少保留1个运行记录
- 自动清理过期的历史记录，节省存储空间

## 环境变量和密钥配置

### 必需的GitHub Secrets
该工作流使用内置的GitHub令牌，无需额外配置Secrets：
- `${{ github.token }}`: GitHub自动提供的令牌

### 环境变量
工作流运行时自动设置的变量：
- `${{ github.repository }}`: 当前仓库名称
- `${{ matrix.* }}`: 矩阵策略中定义的变量

### 输出变量
- `immortalwrt_commitHash`: 最新的提交哈希值

## 触发机制详解

### 1. 定时触发
```yaml
schedule:
  - cron: 0 20 * * *
```
- **执行时间**: 每天UTC 20:00（北京时间凌晨4:00）
- **选择原因**: 避开高峰期，确保资源充足
- **频率**: 每日检查，平衡及时性和资源消耗

### 2. 手动触发
```yaml
workflow_dispatch:
```
- **使用场景**: 
  - 测试工作流
  - 紧急检查更新
  - 调试问题
- **操作方式**: GitHub仓库 → Actions → 选择工作流 → Run workflow

### 3. 下游触发
当检测到更新时，自动触发：
```yaml
event-type: immortalwrt-update
```

## 输出结果和产物

### 1. 直接输出
- **缓存文件**: `.immortalwrt_commitHash`
- **日志信息**: 提交哈希值比较结果

### 2. 触发效果
- **成功检测到更新**: 触发 `immortalwrt-update` 事件
- **无更新**: 工作流正常结束，不触发下游
- **清理完成**: 删除过期的工作流运行记录

### 3. 监控指标
- **工作流状态**: 成功/失败
- **缓存命中率**: 判断更新频率
- **触发次数**: 统计实际更新频率

## 使用指南

### 1. 基础配置
将文件放置在仓库的 `.github/workflows/` 目录下：
```
your-repo/
├── .github/
│   └── workflows/
│       ├── Openwrt-update-checker.yml
│       └── immortalwrt-x86-64.yml
```

### 2. 自定义监控目标
修改矩阵配置以监控不同的仓库或分支：
```yaml
strategy:
  matrix:
    include:
      - repo: immortalwrt/immortalwrt
        branch: openwrt-24.10
        hash_key: immortalwrt_commitHash
        event: immortalwrt-update
      # 添加更多监控目标
      - repo: openwrt/openwrt
        branch: main
        hash_key: openwrt_commitHash
        event: openwrt-update
```

### 3. 调整检查频率
修改cron表达式：
```yaml
schedule:
  - cron: 0 */6 * * *  # 每6小时检查一次
  # 或
  - cron: 0 8,20 * * *  # 每天8:00和20:00检查
```

### 4. 配置下游工作流
确保编译工作流能够响应触发事件：
```yaml
# 在 immortalwrt-x86-64.yml 中
on:
  workflow_dispatch:
  repository_dispatch:
    types: [immortalwrt-update]  # 监听更新事件
```

## 故障排查

### 1. 常见问题

**问题**: 工作流运行失败
```bash
# 检查步骤：
1. 查看Actions日志中的错误信息
2. 确认网络连接是否正常
3. 检查仓库权限设置
```

**问题**: 未触发下游工作流
```bash
# 排查方法：
1. 确认下游工作流的触发条件配置正确
2. 检查repository_dispatch事件类型是否匹配
3. 验证仓库权限是否足够
```

**问题**: 缓存问题导致重复触发
```bash
# 解决方案：
1. 手动清理Actions缓存
2. 检查哈希值获取逻辑
3. 验证缓存键的唯一性
```

### 2. 调试技巧

**启用详细日志**：
```yaml
- name: 调试信息
  run: |
    echo "当前哈希值: ${{ steps.getHash.outputs.immortalwrt_commitHash }}"
    echo "缓存状态: ${{ steps.cacheHash.outputs.cache-hit }}"
```

**测试触发机制**：
```yaml
- name: 测试触发
  if: always()  # 强制执行
  uses: peter-evans/repository-dispatch@v3
  with:
    event-type: test-event
```

## 自定义配置

### 1. 多仓库监控
```yaml
strategy:
  matrix:
    include:
      - repo: immortalwrt/immortalwrt
        branch: openwrt-24.10
        hash_key: immortalwrt_24_10_hash
        event: immortalwrt-24-10-update
      - repo: immortalwrt/immortalwrt
        branch: master
        hash_key: immortalwrt_master_hash
        event: immortalwrt-master-update
```

### 2. 添加通知功能
```yaml
- name: 发送通知
  if: steps.cacheHash.outputs.cache-hit != 'true'
  uses: 8398a7/action-slack@v3
  with:
    status: custom
    custom_payload: |
      {
        text: "ImmortalWrt 源码已更新，开始编译新固件"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 3. 增强错误处理
```yaml
- name: 错误处理
  if: failure()
  run: |
    echo "工作流执行失败，请检查日志"
    # 可以添加错误通知逻辑
```

## 最佳实践

### 1. 性能优化
- 使用浅克隆减少网络传输
- 合理设置检查频率
- 及时清理历史记录

### 2. 安全考虑
- 使用最小权限原则
- 定期更新Action版本
- 避免在日志中暴露敏感信息

### 3. 维护建议
- 定期检查工作流状态
- 监控触发频率和成功率
- 根据实际需求调整配置

该工作流与ImmortalWrt编译工作流配合使用，形成完整的自动化固件构建系统，确保始终使用最新的源码进行编译。
