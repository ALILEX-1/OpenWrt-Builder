#!/bin/bash
#
# 安全检查脚本
# 用于检查代码中是否包含敏感信息
#

echo "🔍 OpenWrt 项目安全检查"
echo "======================="

# 检查是否有硬编码的敏感信息
echo "检查硬编码敏感信息..."

# 定义敏感信息模式
SENSITIVE_PATTERNS=(
    "pppoe_username=\"[^y][^o][^u].*\""  # 不是 your_pppoe_username 的用户名
    "pppoe_password=\"[^y][^o][^u].*\""  # 不是 your_pppoe_password 的密码
    "password=\"[^p][^a][^s].*\""        # 不是 password 的密码
    "[0-9]{8,}"                          # 8位以上数字（可能是账号）
)

FOUND_ISSUES=0

# 检查主要文件
FILES_TO_CHECK=(
    "immortalwrt/diy-part2-x86-64-router.sh"
    ".github/workflows/immortalwrt-x86-64.yml"
    "README.md"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        echo "检查文件: $file"
        
        # 检查是否包含真实的PPPoE账号（数字开头的长字符串）
        if grep -q "pppoe_username=\"[0-9]" "$file" 2>/dev/null; then
            echo "⚠️  警告: $file 中可能包含真实的PPPoE用户名"
            FOUND_ISSUES=$((FOUND_ISSUES + 1))
        fi
        
        # 检查是否包含真实的密码（不是默认值）
        if grep -q "pppoe_password=\"[^y][^o][^u]" "$file" 2>/dev/null; then
            echo "⚠️  警告: $file 中可能包含真实的PPPoE密码"
            FOUND_ISSUES=$((FOUND_ISSUES + 1))
        fi
        
        # 检查是否有其他可疑的敏感信息
        if grep -E "password=\"[^p][^a][^s][^s][^w][^o][^r][^d]" "$file" 2>/dev/null; then
            echo "⚠️  警告: $file 中可能包含真实密码"
            FOUND_ISSUES=$((FOUND_ISSUES + 1))
        fi
    else
        echo "⚠️  文件不存在: $file"
    fi
done

echo
echo "检查 GitHub Secrets 使用情况..."

# 检查是否正确使用了环境变量
if grep -q "PPPOE_USERNAME" .github/workflows/immortalwrt-x86-64.yml 2>/dev/null; then
    echo "✅ GitHub Actions 工作流已配置使用 PPPOE_USERNAME"
else
    echo "❌ GitHub Actions 工作流未配置 PPPOE_USERNAME"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
fi

if grep -q "PPPOE_PASSWORD" .github/workflows/immortalwrt-x86-64.yml 2>/dev/null; then
    echo "✅ GitHub Actions 工作流已配置使用 PPPOE_PASSWORD"
else
    echo "❌ GitHub Actions 工作流未配置 PPPOE_PASSWORD"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
fi

# 检查脚本是否正确使用环境变量
if grep -q "\${PPPOE_USERNAME" immortalwrt/diy-part2-x86-64-router.sh 2>/dev/null; then
    echo "✅ diy-part2 脚本已配置使用环境变量"
else
    echo "❌ diy-part2 脚本未正确配置环境变量"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
fi

echo
echo "安全建议检查..."

# 检查是否有安全日志输出
if grep -q "已隐藏" immortalwrt/diy-part2-x86-64-router.sh 2>/dev/null; then
    echo "✅ 已配置安全日志输出"
else
    echo "⚠️  建议: 配置安全日志输出，避免在日志中显示敏感信息"
fi

# 检查是否有默认值检查
if grep -q "未检测到.*配置" immortalwrt/diy-part2-x86-64-router.sh 2>/dev/null; then
    echo "✅ 已配置默认值检查逻辑"
else
    echo "⚠️  建议: 添加默认值检查，当未配置时使用DHCP模式"
fi

echo
echo "📋 检查结果总结"
echo "==============="

if [ $FOUND_ISSUES -eq 0 ]; then
    echo "🎉 恭喜！未发现安全问题"
    echo "✅ 代码中没有硬编码的敏感信息"
    echo "✅ 已正确配置 GitHub Secrets 使用"
    echo "✅ 安全配置完整"
else
    echo "⚠️  发现 $FOUND_ISSUES 个潜在安全问题"
    echo "请根据上述警告进行修复"
fi

echo
echo "🔐 安全最佳实践提醒："
echo "1. 永远不要在代码中硬编码真实的账号密码"
echo "2. 使用 GitHub Secrets 存储敏感信息"
echo "3. 在日志中隐藏或脱敏敏感信息"
echo "4. 定期检查代码，确保没有意外提交敏感信息"
echo "5. 使用 .gitignore 忽略包含敏感信息的文件"

exit $FOUND_ISSUES
