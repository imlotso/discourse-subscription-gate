# frozen_string_literal: true

require_relative "page_objects/components/gated_topic"

RSpec.describe "Gated topics with groups" do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:group) { Fabricate(:group, name: "premium") }
  fab!(:member, :user)
  fab!(:non_member, :user)

  let!(:theme) { upload_theme_component }
  let(:gated_topic) { PageObjects::Components::GatedTopic.new }

  before do
    group.add(member)
    theme.update_setting(:enabled_categories, category.id.to_s)
    theme.update_setting(:enabled_groups, group.id.to_s)
    theme.save!
  end

  it "does not show gate for user in allowed group" do
    sign_in(member)
    visit(topic.url)
    expect(gated_topic).to have_no_gate
  end

  it "shows group gate with CTA button for user not in allowed group" do
    sign_in(non_member)
    visit(topic.url)
    expect(gated_topic).to have_gate
    expect(gated_topic).to have_group_gate
    expect(gated_topic).to have_group_cta_button
  end

  it "shows anonymous gate (not group gate) for anonymous users" do
    visit(topic.url)
    expect(gated_topic).to have_gate
    expect(gated_topic).to have_signup_gate
  end

  context "when no groups are configured" do
    before do
      theme.update_setting(:enabled_groups, "")
      theme.save!
    end

    it "does not show gate for any logged-in user" do
      sign_in(non_member)
      visit(topic.url)
      expect(gated_topic).to have_no_gate
    end
  end

  context "with multiple groups configured" do
    fab!(:second_group) { Fabricate(:group, name: "vip") }
    fab!(:second_group_member, :user)

    before do
      second_group.add(second_group_member)
      theme.update_setting(:enabled_groups, "\#{group.id}|\#{second_group.id}")
      theme.save!
    end

    it "does not show gate for user in one of the allowed groups" do
      sign_in(second_group_member)
      visit(topic.url)
      expect(gated_topic).to have_no_gate
    end
  end

  context "with only groups configured (no categories or tags)" do
    before do
      theme.update_setting(:enabled_categories, "")
    end

    it "shows gate on any topic for user not in group" do
      sign_in(non_member)
      visit(topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_group_gate
    end
  end

  context "with custom button link" do
    before do
      theme.update_setting(:group_custom_button_link, "https://example.com/subscribe")
      theme.save!
    end

    it "shows group gate with CTA button linking to custom URL" do
      sign_in(non_member)
      visit(topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_group_cta_button
      expect(gated_topic).to have_group_cta_href("https://example.com/subscribe")
    end
  end

  context "with info_topic_id configured" do
    fab!(:info_topic) { Fabricate(:topic) }

    before do
      theme.update_setting(:info_topic_id, info_topic.id.to_s)
      theme.save!
    end

    it "shows info button for logged-in non-member" do
      sign_in(non_member)
      visit(topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_group_gate
      expect(gated_topic).to have_info_button
      expect(gated_topic).to have_info_button_href("/t/-/\#{info_topic.id}")
    end
  end

  context "without info_topic_id" do
    it "does not show info button" do
      sign_in(non_member)
      visit(topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_group_gate
      expect(gated_topic).to have_no_info_button
    end
  end
end

RSpec.describe "Gated topics with topic ids" do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:group) { Fabricate(:group, name: "premium") }
  fab!(:member, :user)
  fab!(:non_member, :user)

  let!(:theme) { upload_theme_component }
  let(:gated_topic) { PageObjects::Components::GatedTopic.new }

  before do
    group.add(member)
    theme.update_setting(:enabled_groups, group.id.to_s)
    theme.save!
  end

  context "with enabled_topic_ids" do
    before do
      theme.update_setting(:enabled_topic_ids, topic.id.to_s)
      theme.save!
      theme.save!
    end

    it "shows gate for anonymous user" do
      visit(topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_signup_gate
    end

    it "shows gate with group CTA for logged-in non-member" do
      sign_in(non_member)
      visit(topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_group_gate
      expect(gated_topic).to have_group_cta_button
    end

    it "does not show gate for member in allowed group" do
      sign_in(member)
      visit(topic.url)
      expect(gated_topic).to have_no_gate
    end
  end

  context "with enabled_topic_id_ranges" do
    fab!(:in_range_topic) { Fabricate(:topic) }
    fab!(:out_range_topic) { Fabricate(:topic) }

    before do
      theme.update_setting(:enabled_topic_id_ranges, "\#{in_range_topic.id}-\#{in_range_topic.id}")
      theme.save!
    end

    it "shows gate for topic in range" do
      sign_in(non_member)
      visit(in_range_topic.url)
      expect(gated_topic).to have_gate
      expect(gated_topic).to have_group_gate
    end

    it "does not show gate for topic out of range" do
      sign_in(non_member)
      visit(out_range_topic.url)
      expect(gated_topic).to have_no_gate
    end
  end
end

RSpec.describe "Gated topics with tags" do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:, tags: ["gated"]) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:group) { Fabricate(:group, name: "premium") }
  fab!(:member, :user)
  fab!(:non_member, :user)

  let!(:theme) { upload_theme_component }
  let(:gated_topic) { PageObjects::Components::GatedTopic.new }

  before do
    group.add(member)
    theme.update_setting(:enabled_groups, group.id.to_s)
    theme.save!
  end

  it "does not show gate when topic does not have gated tag" do
    sign_in(non_member)
    visit(topic.url)
    expect(gated_topic).to have_no_gate
  end

  it "shows gate for anonymous users when topic has gated tag" do
    theme.update_setting(:enabled_tags, "gated")
    theme.save!
    visit(topic.url)
    expect(gated_topic).to have_gate
    expect(gated_topic).to have_signup_gate
  end

  it "shows group gate for logged-in non-member when topic has gated tag" do
    theme.update_setting(:enabled_tags, "gated")
    theme.save!
    sign_in(non_member)
    visit(topic.url)
    expect(gated_topic).to have_gate
    expect(gated_topic).to have_group_gate
    expect(gated_topic).to have_group_cta_button
  end

  it "does not show gate for member in allowed group" do
    theme.update_setting(:enabled_tags, "gated")
    theme.save!
    sign_in(member)
    visit(topic.url)
    expect(gated_topic).to have_no_gate
  end
end