# Discourse Subscription Gate

[📖 简体中文文档](README.zh-CN.md) | **English**

A powerful Discourse theme component that transforms your community into a subscription-ready content platform with paywall overlays, granular access controls, and Stripe integration.

---

## 🌟 Overview

**Discourse Subscription Gate** is an enterprise-grade paywall and membership gating component for Discourse. Unlike simple login gates, it offers fine-grained access rules, tiered membership gating, preview height adjustments, direct Stripe checkout integration, and an intuitive dual-stage CTA user journey for anonymous visitors and logged-in non-subscribers.

Official Website / Community: [SiteTalk (www.sitetalk.net)](https://www.sitetalk.net)

---

## ✨ Key Features

- **Multi-Level Gating Rules**:
  - **Categories**: Gate entire categories (`enabled_categories`).
  - **Tags**: Gate topics bearing specific tags (`enabled_tags`).
  - **Specific Topic IDs**: Gate individual topics by ID (`enabled_topic_ids`, e.g., `103|105|110`).
  - **Topic ID Ranges**: Gate batches of consecutive topics (`enabled_topic_id_ranges`, e.g., `100-120|200-220`).
- **Exempt Topic Whitelist (`exempt_topic_ids`)**:
  - Highest-priority bypass whitelist. Whitelisted topics are completely open regardless of category, tag, or range rules (ideal for free previews, welcome topics, and announcements).
- **Category-to-Group Mapping (`category_group_mappings`)**:
  - Map specific categories to different user groups (e.g., `2:10|3:12` maps Category 2 to Group 10, Category 3 to Group 12), enabling multi-tier memberships (Gold, Diamond, etc.).
- **Stripe & Subscription Checkout Integration**:
  - Seamlessly links to `/s` or directly to `/s/:product_id` via `subscription_product_id`.
- **Dual-Stage CTA Flow**:
  - **Anonymous Visitors**: Primary "Subscribe / Sign Up" button + clean secondary "Already have an account? Sign in" text link.
  - **Logged-in Non-Subscribers**: Dedicated "Subscribe" CTA linking straight to your checkout page.
- **Subscription Details Button (`info_topic_id`)**:
  - Optional secondary link pointing to an internal Discourse topic (`/t/-/:topic_id`) that explains subscription benefits, terms, and FAQs.
- **Visual & UI Customization**:
  - **Visible Preview Height (`content_visible_height`)**: Control how much teaser content users can read before the overlay (relative to viewport height `vh`, default `50`).
  - **Top Overlay Dimming (`top_content_overlay_opacity`)**: Semi-transparent dark overlay covering content under the gate.
  - **Table of Contents (TOC) Dimming (`toc_dim_opacity`)**: Automatically dims Discourse TOC to keep focus on the subscription prompt.
  - **Custom Panel Background (`gate_overlay_bg_color`)**: Customize the floating gate panel color.
- **Admin Diagnostic Panel**:
  - Built-in `<details>` debugging panel visible only to administrators, showing real-time gating evaluation states and rule matches.
- **Modern Glimmer Architecture**:
  - Rebuilt with modern `@glimmer/component` and reactive getters, fully compliant with modern Discourse standards.

---

## 🚀 Installation

1. Go to your Discourse Admin panel: **Admin -> Customize -> Themes -> Components**.
2. Click **Install**.
3. Select **From a git repository**.
4. Enter the repository URL:
   ```text
   https://github.com/imlotso/discourse-subscription-gate.git
   ```
5. Click **Install**.
6. Enable the component on your active themes.

---

## ⚙️ Configuration Reference

All settings can be configured in your Discourse Admin under theme component settings:

| Setting Key | Type | Default | Description |
| :--- | :---: | :---: | :--- |
| `enabled_categories` | list | `""` | Categories requiring subscription to view full content. |
| `enabled_tags` | list | `""` | Tags requiring subscription to view content. |
| `enabled_groups` | list | `""` | User groups permitted to view content. Leave empty to allow all logged-in users. |
| `enabled_topic_ids` | string | `""` | Specific topic IDs requiring subscription, separated by `\|` (e.g., `103\|105\|110`). |
| `enabled_topic_id_ranges` | string | `""` | Topic ID ranges requiring subscription (e.g., `100-120\|200-220`). |
| `exempt_topic_ids` | string | `""` | **Exempt whitelist**: Topic IDs that bypass gating under all circumstances (e.g., `50\|60`). |
| `category_group_mappings` | string | `""` | Multi-category group mappings, format: `cat_id:group_id\|cat_id:group_id`. |
| `subscription_page_url` | string | `"/s"` | Target URL for the subscription CTA button. |
| `subscription_product_id` | string | `""` | Optional Stripe Product ID. When set, CTA button links directly to `/s/:product_id`. |
| `info_topic_id` | string | `""` | Internal topic ID for subscription details. Displays a secondary text link when set. |
| `info_button_label_custom`| string | `"订阅说明"` | Text label for the subscription details link. |
| `content_visible_height` | string | `"50"` | Visible content preview height in `vh` (percentage of viewport height). |
| `top_content_overlay_opacity` | string | `"55"` | Dimming opacity of the content overlay (0–100). |
| `toc_dim_opacity` | string | `"40"` | Opacity of the table of contents when gate is active (0–100). |
| `gate_overlay_bg_color` | string | `"#EAF3FB"`| Background color of the gate bottom panel. |
| `heading_text_custom` | string | `"此内容仅限订阅会员查看"` | Heading text shown in the paywall panel. |
| `subheading_text_custom` | string | `"订阅后即可阅读全部内容。"` | Subheading shown to anonymous visitors. |
| `group_subheading_text_custom` | string | `"您需要有效订阅才能查看此内容。"` | Subheading shown to logged-in non-subscribers. |
| `signup_cta_label_custom` | string | `"立即订阅"` | Primary button label for anonymous visitors. |
| `group_cta_label_custom` | string | `"前往订阅"` | Primary button label for logged-in non-subscribers. |
| `login_cta_label_custom` | string | `"已有账户？登录"` | Secondary login text link label for anonymous visitors. |
| `redirect_after_login` | string | `"true"` | Whether to redirect user back to the gated topic after logging in. |
| `skip_gate_for_logged_in` | string | `"false"` | Global bypass: allows all logged-in users to bypass gate regardless of group. |
| `group_custom_button_link` | string | `""` | *(Deprecated)* Preserved for backward compatibility. |

---

## 🛠️ Architecture & Gating Logic

The gating evaluation follows a strict two-stage pipeline:

1. **Gating Trigger Determination**:
   - Checks if the topic is whitelisted in `exempt_topic_ids`. If yes, **never gate**.
   - Checks if `skip_gate_for_logged_in` is true and user is authenticated. If yes, **never gate**.
   - Checks if the topic matches any trigger: `enabled_categories`, `enabled_tags`, `enabled_topic_ids`, or `enabled_topic_id_ranges`.
   - If no trigger matches, the topic is **open to everyone**.
2. **User Pass-Through Verification**:
   - If the topic is gated, checks if the user belongs to `category_group_mappings` (for that category) or `enabled_groups`.
   - If user is in the authorized group, **access granted**.
   - Otherwise, display the gate with appropriate CTA based on login state.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
