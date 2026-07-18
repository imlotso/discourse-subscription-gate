/* eslint-disable discourse/no-onclick */
import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import bodyClass from "discourse/helpers/body-class";
import routeAction from "discourse/helpers/route-action";
import { fn } from "@ember/helper";
import { i18n } from "discourse-i18n";

export default class TopicInGatedCategory extends Component {
  @service currentUser;

  constructor(...args) {
    super(...args);
    this.recalculate();
    this._applySettings();
  }

  didReceiveArgs() {
    super.didReceiveArgs(...arguments);
    this._applySettings();
  }

  // Parse enabled category ID list (getter for lazy evaluation, matching official pattern)
  get enabledCategories() {
    return (
      settings.enabled_categories
        ?.split("|")
        .map((id) => parseInt(id, 10))
        .filter((id) => id) || []
    );
  }

  // Parse enabled tag list
  get enabledTags() {
    return settings.enabled_tags?.split("|").filter(Boolean) || [];
  }

  // Parse enabled group ID list
  get enabledGroups() {
    return (
      settings.enabled_groups
        ?.split("|")
        .map((id) => parseInt(id, 10))
        .filter((id) => !isNaN(id)) || []
    );
  }

  // Parse enabled topic ID list
  get enabledTopicIds() {
    const raw = settings.enabled_topic_ids;
    if (!raw || raw.trim() === "") {
      return [];
    }
    return raw
      .split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id) && id > 0);
  }

  // Parse enabled topic ID ranges [start, end]
  get enabledTopicIdRanges() {
    const rangesStr = settings.enabled_topic_id_ranges;
    if (!rangesStr || rangesStr.trim() === "") {
      return [];
    }
    const pairs = rangesStr.split("|");
    const ranges = [];
    for (const pair of pairs) {
      const parts = pair.split("-");
      if (parts.length === 2) {
        const start = parseInt(parts[0], 10);
        const end = parseInt(parts[1], 10);
        if (!isNaN(start) && !isNaN(end) && start <= end) {
          ranges.push([start, end]);
        }
      }
    }
    return ranges;
  }

  // Parse exempt topic ID whitelist
  get enabledExemptTopicIds() {
    const raw = settings.exempt_topic_ids;
    if (!raw || raw.trim() === "") {
      return [];
    }
    return raw
      .split("|")
      .map((id) => parseInt(id, 10))
      .filter((id) => !isNaN(id) && id > 0);
  }

  // Parse category-to-group mappings
  get _categoryGroupMappings() {
    const mappingsStr = settings.category_group_mappings;
    if (!mappingsStr) {
      return {};
    }
    const result = {};
    const pairs = mappingsStr.split("|");
    for (const pair of pairs) {
      const parts = pair.split(":");
      if (parts.length === 2) {
        const catId = parseInt(parts[0], 10);
        const groupId = parseInt(parts[1], 10);
        if (!isNaN(catId) && !isNaN(groupId)) {
          result[catId] = groupId;
        }
      }
    }
    return result;
  }

  recalculate() {
    // No-op: lazy getters handle settings evaluation
  }

  _applySettings() {
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

  willDestroy() {
    super.willDestroy(...arguments);
    document.documentElement.style.removeProperty("--gated-topic-bg");
    document.documentElement.style.removeProperty("--gated-content-height");
    document.documentElement.style.removeProperty("--toc-dim-opacity");
    document.documentElement.style.removeProperty(
      "--top-content-overlay-opacity"
    );
  }

  // Get effective group ID for current category
  _getEffectiveGroupId() {
    const catId = this.args?.outletArgs?.model?.category_id;
    if (this._categoryGroupMappings[catId]) {
      return this._categoryGroupMappings[catId];
    }
    return null;
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

  // EXEMPT whitelist check -- highest priority, force bypass
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

  get shouldShow() {
    // 1. Skip gate setting: if enabled, all logged-in users bypass
    if (settings.skip_gate_for_logged_in === "true" && this.currentUser) {
      return false;
    }

    // 2. EXEMPT whitelist -- highest priority, force bypass regardless of anything
    if (this._isExemptTopic()) {
      return false;
    }

    // 3. MASTER GATING: Determine if THIS TOPIC should be gated at all.
    //    ONLY category, tag, topic_id, and topic_id_range can trigger the gate.
    //    enabled_groups is NOT a trigger -- it only controls user pass-through.
    const model = this.args?.outletArgs?.model;
    const categoryId = model?.category_id;
    const tags = model?.tags;

    const isGatedCategory = this.enabledCategories.includes(categoryId);
    const isGatedTag = tags?.some((t) => {
      const name = typeof t === "string" ? t : t.name;
      return this.enabledTags.includes(name);
    });
    const isGatedTopicId = this._matchesTopicId();

    // No gating rules configured at all -- never show gate
    if (
      this.enabledCategories.length === 0 &&
      this.enabledTags.length === 0 &&
      this.enabledTopicIds.length === 0 &&
      this.enabledTopicIdRanges.length === 0
    ) {
      return false;
    }

    // Topic must match at least ONE gating rule (category OR tag OR topic_id/range)
    if (!isGatedCategory && !isGatedTag && !isGatedTopicId) {
      return false;
    }

    // At this point: the topic IS gated. Now check user permissions.

    // 4. USER PASS-THROUGH: Check if the current user is allowed to view.
    //    enabled_groups and category_group_mappings determine pass-through only.
    if (this._isInValidGroup()) {
      return false;
    }

    // If no groups are configured, any logged-in user bypasses (official behavior).
    // Anonymous users always see the gate when the topic is gated.
    if (this.enabledGroups.length === 0 && this.currentUser) {
      return false;
    }

    return true;
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

  // Backward-compat alias: the template now binds this.ctaHref directly so the
  // logged-in CTA always renders via the subscription product / page URL chain.
  // Kept so external callers/tests referencing groupCtaHref keep working.
  get groupCtaHref() {
    return this.ctaHref;
  }

  get ctaHref() {
    if (settings.subscription_product_id) {
      return `/s/${settings.subscription_product_id}`;
    }
    if (settings.subscription_page_url) {
      return settings.subscription_page_url;
    }
    return "/s";
  }

  // Backward compat for existing references/tests.
  get subscriptionCtaHref() {
    return this.ctaHref;
  }

  get infoButtonHref() {
    const topicId = settings.info_topic_id;
    return topicId ? `/t/-/${topicId}` : null;
  }

  get showInfoButton() {
    return !!settings.info_topic_id;
  }

  get _mappingKeys() {
    return Object.keys(this._categoryGroupMappings || {});
  }

  get topicId() {
    const model = this.args?.outletArgs?.model;
    if (model && model.id) {
      return model.id;
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
      {{bodyClass "topic-in-gated-category"}}

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
              {{! Logged-in, not subscribed }}
              <div class="custom-gated-topic-content--cta__group">
                {{#if this.ctaHref}}
                  <a
                    href={{this.ctaHref}}
                    class="btn btn-large btn-primary custom-gated-topic-cta"
                  >
                    {{this.groupCtaLabel}}
                  </a>
                {{/if}}

                {{#if this.infoButtonHref}}
                  <a
                    href={{this.infoButtonHref}}
                    class="custom-gated-topic-secondary-link"
                  >
                    {{this.infoButtonLabel}}
                  </a>
                {{/if}}
              </div>
            {{else}}
              {{! Anonymous: primary sign-up + secondary (login / info) }}
              <div class="custom-gated-topic-content--cta__signup">
                <DButton
                  @action={{routeAction "showCreateAccount"}}
                  @translatedLabel={{this.signupCtaLabel}}
                  class="btn-primary btn-large custom-gated-topic-cta"
                />
              </div>

              <div class="custom-gated-topic-secondary-actions">
                <a
                  onclick={{fn (routeAction "showLogin")}}
                  class="custom-gated-topic-secondary-link"
                >
                  {{this.loginCtaLabel}}
                </a>

                {{#if this.infoButtonHref}}
                  <a
                    href={{this.infoButtonHref}}
                    class="custom-gated-topic-secondary-link"
                  >
                    {{this.infoButtonLabel}}
                  </a>
                {{/if}}
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
