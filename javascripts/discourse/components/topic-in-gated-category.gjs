/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

@tagName("")
export default class TopicInGatedCategory extends Component {
  hidden = true;

  // 解析启用的分类 ID 列表
  enabledCategories =
    settings.enabled_categories
      ?.split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => id) || [];

  // 解析启用的标签列表
  enabledTags = settings.enabled_tags?.split("|").filter(Boolean) || [];

  // 解析全局启用的用户组 ID 列表
  enabledGroups =
    settings.enabled_groups
      ?.split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id)) || [];

  // 多分类-用户组映射缓存
  _categoryGroupMappings = {};
  _plansCache = [];

  constructor(...args) {
    super(...args);
    this._parseCategoryGroupMappings();
    // 异步获取订阅计划数据
    this.fetchSubscriptionPlans();
  }

  // 解析多分类-用户组映射（格式：catId:groupId|catId:groupId）
  _parseCategoryGroupMappings() {
    const mappingsStr = settings.category_group_mappings;
    if (!mappingsStr) {
      this._categoryGroupMappings = {};
      return;
    }
    const pairs = mappingsStr.split("|");
    for (const pair of pairs) {
      const parts = pair.split(":");
      if (parts.length === 2) {
        const catId = parseInt(parts[0], 10);
        const groupId = parseInt(parts[1], 10);
        if (!isNaN(catId) && !isNaN(groupId)) {
          this._categoryGroupMappings[catId] = groupId;
        }
      }
    }
  }

  // 根据当前分类获取应该使用的用户组 ID
  _getEffectiveGroupId() {
    // 如果有分类映射，优先使用映射中的 group
    if (this._categoryGroupMappings[this.categoryId]) {
      return this._categoryGroupMappings[this.categoryId];
    }
    // 否则返回 null，表示使用全局 enabled_groups
    return null;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.recalculate();
    // A4: 设置遮罩背景色 CSS 变量
    if (settings.gate_overlay_bg_color) {
      document.documentElement.style.setProperty(
        "--gated-topic-bg",
        settings.gate_overlay_bg_color
      );
    }
    // A1: 设置帖子内容可见高度 CSS 变量
    if (settings.content_visible_height != null) {
      document.documentElement.style.setProperty(
        "--gated-content-height",
        parseInt(settings.content_visible_height, 10) + "vh"
      );
    }
    // A2: 设置目录透明度 CSS 变量
    if (settings.toc_dim_opacity != null) {
      document.documentElement.style.setProperty(
        "--toc-dim-opacity",
        (parseInt(settings.toc_dim_opacity, 10) / 100).toString()
      );
    }
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    this.recalculate();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    document.body.classList.remove("topic-in-gated-category");
    // 清理 CSS 变量
    document.documentElement.style.removeProperty("--gated-topic-bg");
    document.documentElement.style.removeProperty("--gated-content-height");
    document.documentElement.style.removeProperty("--toc-dim-opacity");
  }

  // 获取当前分类对应的有效用户组 ID（映射优先，回退到全局 enabled_groups）
  get effectiveGroupId() {
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return mappedGroupId;
    }
    // 使用全局 enabled_groups 的第一个组（如有多个，取第一个作为判断依据）
    return this.enabledGroups.length > 0 ? this.enabledGroups[0] : null;
  }

  // 判断用户是否在有效的订阅组中
  _isInValidGroup() {
    if (!this.currentUser?.groups?.length) {
      return false;
    }

    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      // 有分类映射：检查用户是否在该映射组中
      return this.currentUser.groups.some((g) => g.id === mappedGroupId);
    }

    // 无映射：检查用户是否在全局 enabled_groups 中
    return this.currentUser.groups.some((g) =>
      this.enabledGroups.includes(g.id)
    );
  }

  recalculate() {
    // C1 开关：已登录用户直接绕过遮罩
    if (settings.skip_gate_for_logged_in === "true" && this.currentUser) {
      return;
    }

    // 用户在有效订阅组中 — 始终绕过
    if (this._isInValidGroup()) {
      return;
    }

    const hasGroupGating =
      this.enabledGroups.length > 0 ||
      Object.keys(this._categoryGroupMappings).length > 0;

    const gatedByCategory = this.enabledCategories.includes(this.categoryId);
    const gatedByTag = this.tags?.some((t) => {
      const name = typeof t === "string" ? t : t.name;
      return this.enabledTags.includes(name);
    });
    const hasAnyCategoryOrTag =
      this.enabledCategories.length > 0 || this.enabledTags.length > 0;

    if (!hasAnyCategoryOrTag && !hasGroupGating) {
      return;
    }

    // 当配置了分类/标签时，帖子必须匹配其中一个
    if (hasAnyCategoryOrTag && !gatedByCategory && !gatedByTag) {
      return;
    }

    // 未配置任何组限制 — 原始行为：已登录用户绕过
    if (!hasGroupGating && this.currentUser) {
      return;
    }

    document.body.classList.add("topic-in-gated-category");
    this.set("hidden", false);
  }

  @computed("hidden")
  get shouldShow() {
    return !this.hidden;
  }

  // 判断是否显示 group CTA 分支
  // 条件：已登录 + 当前分类有有效的组限制（映射组或全局 enabled_groups）+ 用户不在有效组中
  get showGroupGate() {
    if (!this.currentUser) {
      return false;
    }
    // 有分类映射：检查映射组是否存在
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return true;
    }
    // 无映射：检查全局 enabled_groups 是否配置
    return this.enabledGroups.length > 0;
  }

  // 文案优先级：settings.custom 优先，fallback 到 i18n
  get headingText() {
    return settings.heading_text_custom || i18n(themePrefix("heading_text"));
  }

  get subheadingText() {
    return (
      settings.subheading_text_custom || i18n(themePrefix("subheading_text"))
    );
  }

  get groupSubheadingText() {
    return (
      settings.group_subheading_text_custom ||
      i18n(themePrefix("group_subheading_text"))
    );
  }

  get signupCtaLabel() {
    return (
      settings.signup_cta_label_custom || i18n(themePrefix("signup_cta_label"))
    );
  }

  get groupCtaLabel() {
    return (
      settings.group_cta_label_custom || i18n(themePrefix("group_cta_label"))
    );
  }

  get loginCtaLabel() {
    return (
      settings.login_cta_label_custom || i18n(themePrefix("login_cta_label"))
    );
  }

  // 构建 CTA 按钮的 href 地址
  // 构建 group CTA 按钮的 href 地址
  // 与官方行为一致：仅当 group_custom_button_link 配置时才渲染按钮
  // subscription_product_id / subscription_page_url 留给未登录用户注册流程使用
  get ctaHref() {
    return settings.group_custom_button_link || null;
  }

  // 订阅计划列表数据
  get subscriptionPlans() {
    if (
      !settings.show_subscription_plans ||
      settings.show_subscription_plans === "false" ||
      !settings.plan_display_product_id
    ) {
      return [];
    }
    return this._plansCache || [];
  }

  // 获取订阅计划数据
  async fetchSubscriptionPlans() {
    if (
      !settings.show_subscription_plans ||
      settings.show_subscription_plans === "false" ||
      !settings.plan_display_product_id
    ) {
      return;
    }
    try {
      const response = await ajax(
        "/s/" + settings.plan_display_product_id + ".json",
        {
          method: "GET",
        }
      );
      if (response && response.plans) {
        this._plansCache = response.plans.map((plan) => ({
          name: plan.name || plan.title || "",
          type: plan.type || "",
          price: plan.price ? (plan.price / 100).toFixed(2) : "0.00",
          currency: plan.currency || "USD",
        }));
      }
    } catch {
      // API 请求失败时静默处理，不影响遮罩显示
      // API 请求失败时静默处理，不影响遮罩显示
      this._plansCache = [];
    }
  }

  // 登录成功后跳回原页面
  handleRedirectAfterLogin() {
    if (settings.redirect_after_login !== "false") {
      // 记录触发遮罩前的 URL，登录后跳回
      sessionStorage.setItem(
        "gated_topic_redirect_url",
        window.location.pathname + window.location.search
      );
    }
  }

  // 分类组映射的键列表（供模板使用）
  get _mappingKeys() {
    return Object.keys(this._categoryGroupMappings);
  }

  <template>
    {{#if this.shouldShow}}
      <div class="custom-gated-topic-container">
        <div class="custom-gated-topic-content">
          <div class="custom-gated-topic-content--header">
            {{this.headingText}}
          </div>

          <p class="custom-gated-topic-content--text">
            {{#if this.showGroupGate}}
              {{this.groupSubheadingText}}
            {{else}}
              {{this.subheadingText}}
            {{/if}}
          </p>

          {{! 订阅计划价格列表 }}
          {{#if this.subscriptionPlans}}
            <ul class="gated-plan-list">
              {{#each this.subscriptionPlans as |plan|}}
                <li class="gated-plan-item">
                  {{plan.name}}
                  ·
                  {{plan.price}}{{plan.currency}}
                </li>
              {{/each}}
            </ul>
          {{/if}}

          <div class="custom-gated-topic-content--cta">
            {{#if this.showGroupGate}}
              <div class="custom-gated-topic-content--cta__group">
                {{#if this.ctaHref}}
                  <DButton
                    @href={{this.ctaHref}}
                    class="btn-primary btn-large"
                    @translatedLabel={{this.groupCtaLabel}}
                  />
                {{/if}}
              </div>
            {{else}}
              <div class="custom-gated-topic-content--cta__signup">
                <DButton
                  @action={{routeAction "showCreateAccount"}}
                  class="btn-primary btn-large sign-up-button"
                  @translatedLabel={{this.signupCtaLabel}}
                />
              </div>

              <div class="custom-gated-topic-content--cta__login">
                <DButton
                  @action={{routeAction "showLogin"}}
                  @id="cta-login-link"
                  class="btn btn-text login-button"
                  @translatedLabel={{this.loginCtaLabel}}
                />
              </div>
            {{/if}}
          </div>

          {{! D3: 管理员配置状态面板 }}
          {{#if this.currentUser.admin}}
            <details class="gated-category-admin-info">
              <summary>管理员配置状态</summary>
              <ul>
                <li>启用分类: {{this.enabledCategories}}</li>
                <li>启用标签: {{this.enabledTags}}</li>
                <li>启用组: {{this.enabledGroups}}</li>
                <li>分类组映射: {{this._mappingKeys}}</li>
                <li>skip_gate_for_logged_in:
                  {{settings.skip_gate_for_logged_in}}</li>
                <li>subscription_product_id:
                  {{settings.subscription_product_id}}</li>
                <li>category_group_mappings:
                  {{settings.category_group_mappings}}</li>
              </ul>
            </details>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
