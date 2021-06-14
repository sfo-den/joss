require 'rails_helper'

RSpec.describe Editor, type: :model do
  let(:editor) { create(:editor) }

  describe "#category_list" do
    subject { create(:editor, categories: %w(a b c)).category_list }
    it { is_expected.to eql("a, b, c") }
  end

  describe "#category_list=" do
    let(:editor) { create(:editor, categories: []) }

    it "assigns #categories" do
      expect {
        editor.category_list = "a, b, c"
      }.to change {
        editor.categories
      }.from([]).to(%w(a b c))
    end
  end

  describe "#associations" do
    it "has many votes" do
      association = Editor.reflect_on_association(:votes)
      expect(association.macro).to eq(:has_many)
    end

    it "has many papers" do
      association = Editor.reflect_on_association(:papers)
      expect(association.macro).to eq(:has_many)
    end

    it "has many invitations" do
      association = Editor.reflect_on_association(:invitations)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe "#full_name" do
    subject { editor.full_name }
    it { is_expected.to eql "#{editor.first_name} #{editor.last_name}" }
  end

  context "switching type to topic" do
    before(:each) { editor.update(kind: "board", title: "chief") }

    it "clears the title" do
      expect {
        editor.update(kind: "topic")
      }.to change {
        editor.title
      }.from("chief").to(nil)
    end
  end

  describe "#format_login" do
    let(:editor) { build(:editor, login: "@somebody") }

    it "removes @'s" do
      expect { editor.save }.to change { editor.login }.to "somebody"
    end
  end

  describe "#three_month_average" do
    before(:each) {
      create(:accepted_paper, :editor => editor, :accepted_at => 1.week.ago);
      create(:accepted_paper, :editor => editor, :accepted_at => 3.weeks.ago);
      create(:accepted_paper, :editor => editor, :accepted_at => 4.months.ago)
    }

    it "should know how many papers the editor has published" do
      expect(editor.papers.count).to eq(3)
    end

    it "should know how to calculate the monntly average papers" do
      expect(editor.three_month_average).to eq("0.7")
    end
  end

  describe "#global editor stats" do
    before do
      # This editor should be ignored as they're retired
      retired_editor = create(:editor, login: "@retired1", kind: "emeritus")
      create(:accepted_paper, :editor => retired_editor, :accepted_at => 1.week.ago)
      create(:accepted_paper, :editor => retired_editor, :accepted_at => 1.year.ago)

      # This editor should be ignored as they're brand new
      new_editor = create(:editor, login: "@topic1", kind: "topic")
      create(:accepted_paper, :editor => new_editor, :accepted_at => 1.week.ago)

      # These editors should be the ones that count
      active_editor_1 = create(:editor, login: "@topic1", kind: "topic", :created_at => 4.months.ago)
      create(:accepted_paper, :editor => active_editor_1, :accepted_at => 1.week.ago) #counts
      create(:accepted_paper, :editor => active_editor_1, :accepted_at => 1.year.ago) #doesn't count

      active_editor_2 = create(:editor, login: "@topic1", kind: "topic", :created_at => 4.years.ago)
      create(:accepted_paper, :editor => active_editor_2, :accepted_at => 1.week.ago) #counts
      create(:accepted_paper, :editor => active_editor_2, :accepted_at => 1.month.ago) #counts
    end

    it "should know how to calculate the overall #global_three_month_average" do
      expect(Editor.global_three_month_average).to eq("0.5")
    end
  end

  describe "#active editors" do
    it "should exclude emeritus and pending" do
      editor_1 = create(:editor, login: "@board1", kind: "board")
      editor_2 = create(:editor, login: "@topic1", kind: "topic")
      editor_3 = create(:editor, login: "@retired1", kind: "emeritus")
      editor_3 = create(:editor, login: "@pending1", kind: "pending")

      assert Editor.active.count == 2
      assert Editor.emeritus.count == 1
      assert Editor.pending.count == 1
    end
  end

  describe "#accept!" do
    it "should upgrade a pending editor to a topic editor" do
      editor = create(:pending_editor)

      assert editor.kind = "pending"
      editor.accept!
      assert editor.reload.kind = "topic"
    end

    it "should delete the onboarding invitation" do
      editor = create(:pending_editor)
      create(:onboarding_invitation, email: editor.email)
      create(:onboarding_invitation)

      expect { editor.accept! }.to change(OnboardingInvitation, :count).by(-1)
    end

    it "should not affect non-pending editors" do
      topic_editor = create(:editor)
      board_editor = create(:board_editor)
      emeritus_editor = create(:emeritus_editor)

      topic_editor.accept!
      board_editor.accept!
      emeritus_editor.accept!

      assert topic_editor.reload.kind = "topic"
      assert board_editor.reload.kind = "board"
      assert emeritus_editor.reload.kind = "emeritus"
    end
  end
end
