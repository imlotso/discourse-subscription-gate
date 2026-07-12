/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
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

  // 解析启用的 topic id 列表
  enabledTopicIds =
    settings.enabled_topic_ids
      ?.split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id) && id > 0) || [];

  // 解析启用的 topic id 区间列表 [start, end]
  enabledTopicIdRanges = [];

  constructor(...args) {
    super(...args);
    this._parseCategoryGroupMappings();
    this._parseTopicIdRanges();
  }

  // 解析多分类-用户组映射
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

  // 解析 topic id 区间
  _parseTopicIdRanges() {
    const rangesStr = settings.enabled_topic_id_ranges;
    if (!rangesStr) {
      this.enabledTopicIdRanges = [];
      return;
    }
    const pairs = rangesStr.split("|");
    this.enabledTopicIdRanges = [];
    for (const pair of pairs) {
      const parts = pair.split("-");
      if (parts.length === 2) {
        const start = parseInt(parts[0], 10);
        const end = parseInt(parts[1], 10);
        if (!isNaN(start) && !isNaN(end) && start <= end) {
          this.enabledTopicIdRanges.push([start, end]);
        }
      }
    }
  }

  // 根据当前分类获取应该使用的用户组 ID
  _getEffectiveGroupId() {
    if (this._categoryGroupMappings[this.categoryId]) {
      return this._categoryGroupMappings[this.categoryId];
    }
    return null;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.recalculate();
    // 设置遮罩背景色 CSS 变量
    if (settings.gate_overlay_bg_color) {
      document.documentElement.style.setProperty(
        "--gated-topic-bg",
        settings.gate_overlay_bg_color
      );
    }
    // 设置帖子内容可见高度 CSS 变量
    if (settings.content_visible_height != null) {
      document.documentElement.style.setProperty(
        "--gated-content-height",
        parseInt(settings.content_visible_height, 10) + "vh"
      );
    }
    // 设置目录透明度 CSS 变量
    if (settings.toc_dim_opacity != null) {
      document.documentElement.style.setProperty(
        "--toc-dim-opacity",
        (parseInt(settings.toc_dim_opacity, 10) / 100).toString()
      );
    }
    // 设置上方正文遮罩透明度 CSS 变量
    if (settings.top_content_overlay_opacity != null) {
      const opacity = Math.min(
        1,
        Math.max(0, parseInt(settings.top_content_overlay_opacity, 10) / 100)
      );
      document.documentElement.style.setProperty(
        "--top-content-overlay-opacity",
        opacity.toString()
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
    document.documentElement.style.removeProperty("--gated-topic-bg");
    document.documentElement.style.removeProperty("--gated-content-height");
    document.documentElement.style.removeProperty("--toc-dim-opacity");
    document.documentElement.style.removeProperty(
      "--top-content-overlay-opacity"
    );
  }

  // 获取当前分类对应的有效用户组 ID
  get effectiveGroupId() {
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return mappedGroupId;
    }
    return this.enabledGroups.length > 0 ? this.enabledGroups[0] : null;
  }

  // 判断用户是否在有效的订阅组中
  _isInValidGroup() {
    if (!this.currentUser?.groups?.length) {
      return false;
    }
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return this.currentUser.groups.some((g) => g.id === mappedGroupId);
    }
    return this.currentUser.groups.some((g) =>
      this.enabledGroups.includes(g.id)
    );
  }

  // 判断当前 topic 是否命中 topic id 白名单
  _matchesTopicId() {
    const topicId = this.topicId;
    if (!topicId) {
      return false;
    }
    if (this.enabledTopicIds.includes(topicId)) {
      return true;
    }
    for (const [start, end] of this.enabledTopicIdRanges) {
      if (topicId >= start && topicId <= end) {
        return true;
      }
    }
    return false;
  }

  // gate 判定逻辑
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
    const gatedByTopicId = this._matchesTopicId();
    const hasAnyCategoryOrTag =
      this.enabledCategories.length > 0 || this.enabledTags.length > 0;

    // 无任何 gate 条件配置
    if (!hasAnyCategoryOrTag && !hasGroupGating && !gatedByTopicId) {
      return;
    }

    // 当配置了分类/标签时，topic 必须匹配其中一个
    if (
      hasAnyCategoryOrTag &&
      !gatedByCategory &&
      !gatedByTag &&
      !gatedByTopicId
    ) {
      return;
    }

    // 仅配置了 topic id（无 category/tag/group）
    if (!hasAnyCategoryOrTag && !hasGroupGating && gatedByTopicId) {
      document.body.classList.add("topic-in-gated-category");
      this.set("hidden", false);
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

  // 判断是否显示 group gate（已登录但未订阅用户）
  // 必须与 recalculate 使用同一套 effective group 逻辑
  get showGroupGate() {
    // 匿名用户 → 走 signup gate
    if (!this.currentUser) {
      return false;
    }
    // 有分类映射 → 使用映射组
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return true;
    }
    // 无映射 → 检查全局 enabled_groups 是否配置
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

  get infoButtonLabel() {
    return (
      settings.info_button_label_custom ||
      i18n(themePrefix("info_button_label"))
    );
  }

  // 构建 group CTA 按钮的 href 地址
  // 优先级：group_custom_button_link > subscription_product_id > subscription_page_url > /s
  get ctaHref() {
    if (settings.group_custom_button_link) {
      return settings.group_custom_button_link;
    }
    if (settings.subscription_product_id) {
      return "/s/" + settings.subscription_product_id;
    }
    if (settings.subscription_page_url) {
      return settings.subscription_page_url;
    }
    return "/s";
  }

  // Standard subscription CTA href for logged-in non-member users
  // Fallback order: subscription_product_id > subscription_page_url > /s
  get subscriptionCtaHref() {
    if (settings.subscription_product_id) {
      return "/s/" + settings.subscription_product_id;
    }
    if (settings.subscription_page_url) {
      return settings.subscription_page_url;
    }
    return "/s";
  }

  // Show subscription CTA for logged-in users when group_custom_button_link is empty
  get showSubscriptionCta() {
    if (!this.currentUser) {
      return false;
    }
    if (!settings.group_custom_button_link) {
      return !!this.subscriptionCtaHref;
    }
    return false;
  }

  // 次按钮 href（info_topic_id）
  get infoButtonHref() {
    if (settings.info_topic_id) {
      return "/t/-/" + settings.info_topic_id;
    }
    return null;
  }

  // 判断是否显示次按钮
  get showInfoButton() {
    return !!settings.info_topic_id;
  }

  get _mappingKeys() {
    return Object.keys(this._categoryGroupMappings || {});
  }

  get topicId() {
    // 从 outletArgs 获取当前 topic 的 id
    if (this.args && this.args.model) {
      return this.args.model.id;
    }
    return null;
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

          <div class="custom-gated-topic-content--cta">
            {{#if this.showGroupGate}}
              <div class="custom-gated-topic-content--cta__group">
                {{#if settings.group_custom_button_link}}
                  <DButton
                    @href={{settings.group_custom_button_link}}
                    class="btn-primary btn-large"
                    @translatedLabel={{this.groupCtaLabel}}
                  />
                {{else if this.showSubscriptionCta}}
                  <DButton
                    @href={{this.subscriptionCtaHref}}
                    class="btn-primary btn-large subscription-cta-button"
                    @translatedLabel={{this.groupCtaLabel}}
                  />
                {{/if}}
                {{#if this.showInfoButton}}
                  <DButton
                    @href={{this.infoButtonHref}}
                    class="btn btn-text info-button"
                    @translatedLabel={{this.infoButtonLabel}}
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
                <li>enabled_topic_ids: {{this.enabledTopicIds}}</li>
                <li>enabled_topic_id_ranges: {{this.enabledTopicIdRanges}}</li>
                <li>skip_gate_for_logged_in:
                  {{settings.skip_gate_for_logged_in}}</li>
                <li>subscription_product_id:
                  {{settings.subscription_product_id}}</li>
              </ul>
            </details>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
