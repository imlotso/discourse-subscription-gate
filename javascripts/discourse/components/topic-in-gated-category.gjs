/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";

@tagName("")
export default class TopicInGatedCategory extends Component {
  hidden = true;

  // Parse enabled category ID list
  enabledCategories =
    settings.enabled_categories
      ?.split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => id) || [];

  // Parse enabled tag list
  enabledTags = settings.enabled_tags?.split("|").filter(Boolean) || [];

  // Parse enabled group ID list
  enabledGroups =
    settings.enabled_groups
      ?.split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id)) || [];

  // FIX: empty string returns [] instead of [NaN]
  enabledTopicIds = (() => {
    const raw = settings.enabled_topic_ids;
    if (!raw || raw.trim() === "") return [];
    return raw
      .split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id) && id > 0);
  })();

  // Parse enabled topic ID ranges [start, end]
  enabledTopicIdRanges = [];

  // FIX: exempt_topic_ids whitelist -- empty string returns []
  enabledExemptTopicIds = (() => {
    const raw = settings.exempt_topic_ids;
    if (!raw || raw.trim() === "") return [];
    return raw
      .split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id) && id > 0);
  })();

  constructor(...args) {
    super(...args);
    this._parseCategoryGroupMappings();
    this._parseTopicIdRanges();
  }

  // Parse category-to-group mappings
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

  // FIX: empty string returns []
  _parseTopicIdRanges() {
    const rangesStr = settings.enabled_topic_id_ranges;
    if (!rangesStr || rangesStr.trim() === "") {
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

  // Get effective group ID for current category
  _getEffectiveGroupId() {
    if (this._categoryGroupMappings[this.categoryId]) {
      return this._categoryGroupMappings[this.categoryId];
    }
    return null;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.recalculate();
    if (settings.gate_overlay_bg_color) {
      document.documentElement.style.setProperty(
        "--gated-topic-bg",
        settings.gate_overlay_bg_color
      );
    }
    if (settings.content_visible_height != null) {
      document.documentElement.style.setProperty(
        "--gated-content-height",
        parseInt(settings.content_visible_height, 10) + "vh"
      );
    }
    if (settings.toc_dim_opacity != null) {
      document.documentElement.style.setProperty(
        "--toc-dim-opacity",
        (parseInt(settings.toc_dim_opacity, 10) / 100).toString()
      );
    }
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

  get effectiveGroupId() {
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return mappedGroupId;
    }
    return this.enabledGroups.length > 0 ? this.enabledGroups[0] : null;
  }

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

  // FIX: exempt whitelist check -- highest priority
  _isExemptTopic() {
    const topicId = this.topicId;
    if (!topicId) {
      return false;
    }
    return this.enabledExemptTopicIds.includes(topicId);
  }

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

  recalculate() {
    if (settings.skip_gate_for_logged_in === "true" && this.currentUser) {
      return;
    }

    // EXEMPT whitelist -- highest priority, force bypass
    if (this._isExemptTopic()) {
      return;
    }

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

    if (!hasAnyCategoryOrTag && !hasGroupGating && !gatedByTopicId) {
      return;
    }

    if (
      hasAnyCategoryOrTag &&
      !gatedByCategory &&
      !gatedByTag &&
      !gatedByTopicId
    ) {
      return;
    }

    if (!hasAnyCategoryOrTag && !hasGroupGating && gatedByTopicId) {
      document.body.classList.add("topic-in-gated-category");
      this.set("hidden", false);
      return;
    }

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

  get showGroupGate() {
    if (!this.currentUser) {
      return false;
    }
    const mappedGroupId = this._getEffectiveGroupId();
    if (mappedGroupId) {
      return true;
    }
    return this.enabledGroups.length > 0;
  }

  // Backward compat: group_custom_button_link passthrough for official QUnit test
  get groupCustomButtonLink() {
    return settings.group_custom_button_link || "";
  }

  // Unified subscription CTA href
  get subscriptionCtaHref() {
    if (settings.subscription_product_id) {
      return "/s/" + settings.subscription_product_id;
    }
    if (settings.subscription_page_url) {
      return settings.subscription_page_url;
    }
    return "/s";
  }

  get infoButtonHref() {
    if (settings.info_topic_id) {
      return "/t/-/" + settings.info_topic_id;
    }
    return null;
  }

  get showInfoButton() {
    return !!settings.info_topic_id;
  }

  get _mappingKeys() {
    return Object.keys(this._categoryGroupMappings || {});
  }

  get topicId() {
    if (this.args && this.args.model) {
      return this.args.model.id;
    }
    return null;
  }

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
                {{! Backward compat: when group_custom_button_link is set, render old .btn-primary anchor }}
                {{#if this.groupCustomButtonLink}}
                  <a
                    href={{this.groupCustomButtonLink}}
                    class="btn btn-primary group-custom-cta"
                  >
                    {{this.groupCtaLabel}}
                  </a>
                {{! New behavior: subscription CTA for logged-in non-members }}
                {{else}}
                  <a
                    href={{this.subscriptionCtaHref}}
                    class="btn btn-large btn-subscription"
                  >
                    {{this.groupCtaLabel}}
                  </a>
                  {{#if this.showInfoButton}}
                    <a
                      href={{this.infoButtonHref}}
                      class="btn btn-text info-button"
                    >
                      {{this.infoButtonLabel}}
                    </a>
                  {{/if}}
                {{/if}}
              </div>
            {{else}}
              <div class="custom-gated-topic-content--cta__signup">
                <button
                  type="button"
                  class="btn btn-large btn-primary sign-up-button"
                  onclick={{fn (routeAction "showCreateAccount")}}
                >
                  {{this.signupCtaLabel}}
                </button>
              </div>

              <div class="custom-gated-topic-content--cta__login">
                <a
                  href="#"
                  id="cta-login-link"
                  class="btn btn-text login-button"
                  onclick={{fn (routeAction "showLogin")}}
                >
                  {{this.loginCtaLabel}}
                </a>
              </div>
            {{/if}}
          </div>

          {{! Admin config status panel }}
          {{#if this.currentUser.admin}}
            <details class="gated-category-admin-info">
              <summary>Admin Config</summary>
              <ul>
                <li>enabledCategories: {{this.enabledCategories}}</li>
                <li>enabledTags: {{this.enabledTags}}</li>
                <li>enabledGroups: {{this.enabledGroups}}</li>
                <li>mappings: {{this._mappingKeys}}</li>
                <li>enabledTopicIds: {{this.enabledTopicIds}}</li>
                <li>enabledTopicIdRanges: {{this.enabledTopicIdRanges}}</li>
                <li>exemptTopicIds: {{this.enabledExemptTopicIds}}</li>
                <li>skipGate: {{settings.skip_gate_for_logged_in}}</li>
                <li>prodId: {{settings.subscription_product_id}}</li>
              </ul>
            </details>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}