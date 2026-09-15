# Discourse Subscription Gate (订阅门槛与付费墙组件)

**简体中文** | [English](README.md)

一款专为 Discourse 社区打造的高级付费墙与会员订阅门槛主题组件，支持精细化的访问权限控制、Stripe 订阅直连、优雅的双层 CTA 转化路径与丰富的视觉试读定制。

---

## 🌟 概述

**Discourse Subscription Gate** 是对官方基础组件的全面增强与重构。它不再仅仅是一个粗糙的“防访客登录提示框”，而是一套完整的**社区内容付费变现与会员等级分层体系**。

无论是按照分类、标签全局锁定，还是锁定单篇精选文章、连续话题区间，亦或是为不同版块绑定不同的会员等级，本组件均能完美支持。

官方站点与交流社区：[SiteTalk (www.sitetalk.net)](https://www.sitetalk.net)

---

## ✨ 核心特性

- **多层级门槛规则 (Gating Triggers)**：
  - **按分类锁定 (`enabled_categories`)**：指定全部分类均需订阅。
  - **按标签锁定 (`enabled_tags`)**：带有指定标签的话题需订阅。
  - **按单话题 ID 锁定 (`enabled_topic_ids`)**：支持竖线分隔的精确 ID（如 `103|105|110`），适合对单篇精选/付费专栏文章单独锁门槛。
  - **按话题 ID 区间锁定 (`enabled_topic_id_ranges`)**：支持范围语法（如 `100-120|200-220`），适合批量管理连续编号的付费帖子。
- **免密白名单豁免机制 (`exempt_topic_ids`)**：
  - **最高优先级**。白名单内的话题（如 `50|60`）直接对所有人完全放行，无视分类、标签或 ID 规则，非常适合放置免费试读帖、新手指南或置顶公告。
- **分类与用户组精准映射 (`category_group_mappings`)**：
  - 支持 `category_id:group_id|category_id:group_id` 格式，打破官方所有版块共享单一用户组的限制，轻松实现“黄金版块需黄金组、钻石版块需钻石组”的多阶梯会员制。
- **Stripe 与商品直连订阅**：
  - 支持配置通用订阅页面路径 `subscription_page_url`（默认 `/s`）。
  - 支持填写 `subscription_product_id`，用户点击 CTA 按钮时直接跳转至 `/s/:product_id` 一键直达结账。
- **访客与未订阅用户分层 CTA 引导**：
  - **未登录访客**：显示醒目的主按钮（“立即订阅/注册”），下方搭配轻量优雅的灰色下划线文本链接（“已有账户？登录”）。
  - **已登录未订阅用户**：显示“前往订阅”主按钮，直接引导进入购买页面。
- **订阅说明指引入口 (`info_topic_id`)**：
  - 支持配置一个内部说明帖 ID（如权益说明、退款须知），配置后将在主按钮下方展示“订阅说明”文本链接（`/t/-/:topic_id`），有效提升付费转化率。
- **试读视觉深度定制**：
  - **试读可见高度 (`content_visible_height`)**：自定义遮盖前正文露出的高度（视口高度百分比 `vh`，默认 `50`）。
  - **上方半透明遮罩 (`top_content_overlay_opacity`)**：正文区域蒙上可调节透明度的暗色黑幕，提升高级感同时防止被轻易辨识。
  - **目录树智能暗化 (`toc_dim_opacity`)**：右侧 TOC 目录在遮罩激活时自动降低透明度（默认 40%），突出订阅面板。
  - **底板颜色可配 (`gate_overlay_bg_color`)**：通过 CSS 变量自由调节浮动面板背景色。
- **管理员实时诊断面板 (Admin Diagnostic Panel)**：
  - 管理员浏览受限页面时，底部自动显示可折叠的 `<details>` 状态面板，实时展示当前话题匹配的各项规则与放行状态。
- **现代化 Glimmer 架构**：
  - 全面迁移至 Glimmer Component 架构，消除了旧版 Ember Classic Component 的性能与兼容性隐患，严格遵循 Discourse 2026 最新开发规范。

---

## 🚀 安装步骤

1. 登录 Discourse 管理员后台：**管理 (Admin) -> 定制 (Customize) -> 主题 (Themes) -> 组件 (Components)**。
2. 点击 **安装 (Install)** 按钮。
3. 选择 **从 Git 仓库 (From a git repository)**。
4. 输入仓库 Git 地址：
   ```text
   https://github.com/imlotso/discourse-subscription-gate.git
   ```
5. 点击 **安装** 完成下载。
6. 将组件添加到已启用的主主题上即可生效。

---

## ⚙️ 详细配置项说明 (Settings Reference)

在组件的设置面板中，可对以下所有项进行配置：

| 配置项 (Key) | 类型 | 默认值 | 说明与示例 |
| :--- | :---: | :---: | :--- |
| `enabled_categories` | list | `""` | 需要订阅才能查看完整内容的分类列表 |
| `enabled_tags` | list | `""` | 需要订阅才能查看内容的标签列表 |
| `enabled_groups` | list | `""` | 允许查看内容的用户组，留空则代表允许所有已登录用户 |
| `enabled_topic_ids` | string | `""` | 需要订阅才能查看的话题 ID 列表，用 `\|` 分隔，例如：`103\|105\|110` |
| `enabled_topic_id_ranges` | string | `""` | 需要订阅的话题 ID 区间，格式：`start-end`，多个用 `\|` 分隔，例如：`100-120\|200-220` |
| `exempt_topic_ids` | string | `""` | **免密白名单**话题 ID，配置后无视订阅限制直接完全开放，用 `\|` 分隔，例如：`50\|60` |
| `category_group_mappings` | string | `""` | 分类对应不同用户组的映射，格式：`category_id:group_id\|category_id:group_id` |
| `subscription_page_url` | string | `"/s"` | 订阅页面 URL，CTA 按钮跳转的目标地址 |
| `subscription_product_id` | string | `""` | Stripe 商品 ID，填写后 CTA 按钮将直接跳转至 `/s/:product_id` |
| `info_topic_id` | string | `""` | “订阅说明”按钮跳转的内部话题 ID，填写后主按钮下方会展示次级文本链接 |
| `info_button_label_custom`| string | `"订阅说明"` | 次级“订阅说明”文本链接的文案 |
| `content_visible_height` | string | `"50"` | 帖子内容在遮盖下可见的高度百分比（相对视口高度 `vh`，默认 50） |
| `top_content_overlay_opacity`| string | `"55"` | 上方正文区域遮盖暗色透明度百分比（0-100，如 55 代表 0.55） |
| `toc_dim_opacity` | string | `"40"` | 遮罩激活时，右侧目录（TOC）的透明度百分比（默认 40%） |
| `gate_overlay_bg_color` | string | `"#EAF3FB"`| 遮盖底部浮动面板的背景色 |
| `heading_text_custom` | string | `"此内容仅限订阅会员查看"` | 遮盖卡片大标题文字 |
| `subheading_text_custom` | string | `"订阅后即可阅读全部内容。"` | 未登录访客看到的副标题文字 |
| `group_subheading_text_custom`| string | `"您需要有效订阅才能查看此内容。"`| 已登录未订阅用户看到的副标题文字 |
| `signup_cta_label_custom` | string | `"立即订阅"` | 未登录访客主按钮文案 |
| `group_cta_label_custom` | string | `"前往订阅"` | 已登录未订阅用户主按钮文案 |
| `login_cta_label_custom` | string | `"已有账户？登录"` | 未登录访客看到的次级登录文本链接文案 |
| `redirect_after_login` | string | `"true"` | 用户登录后是否自动跳回触发遮盖的原帖子页面 |
| `skip_gate_for_logged_in` | string | `"false"` | 是否允许所有已登录用户绕过遮盖（全员放行降级开关） |
| `group_custom_button_link` | string | `""` | *[已弃用]* 已登录用户自定义跳转链接，保留以兼容官方 QUnit 测试 |

---

## 🛠️ 权限判定与运行机制

本组件的核心判定逻辑经过重构，严格遵循两阶段分离架构，杜绝全站误锁：

1. **第一阶段：门槛触发判定 (Gating Trigger)**
   - 检查是否命中 `exempt_topic_ids` 白名单：若命中，**绝对不遮罩**。
   - 检查是否开启 `skip_gate_for_logged_in` 且已登录：若满足，**绝对不遮罩**。
   - 检查当前话题是否匹配 `enabled_categories`、`enabled_tags`、`enabled_topic_ids` 或 `enabled_topic_id_ranges`。
   - 若均不匹配，说明该话题不属于受限内容，**直接开放**。
2. **第二阶段：用户通行判定 (User Pass-Through)**
   - 在确定当前话题受限后，判断当前用户是否属于 `category_group_mappings`（若当前分类有专门映射）或 `enabled_groups`。
   - 如果属于授权组，**放行阅读**。
   - 如果不属于授权组，按照用户是否登录展示对应的专属遮罩与引导 CTA。

---

## 📄 开源许可

本项目遵循 [MIT License](LICENSE) 协议。
