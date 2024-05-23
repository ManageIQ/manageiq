RSpec.describe 'SupportsHelper' do
  include Spec::Support::SupportsHelper

  before do
    stub_const('Post', Class.new do
      include SupportsFeatureMixin
      supports :archive
      supports_not :delete
      supports(:archive_ref) { unsupported_reason(:archive) }
      supports(:delete_ref)  { unsupported_reason(:delete) }
    end)
  end

  context "stub_supports" do
    it "starts as false" do
      expect(Post.supports?(:delete)).to be false
    end

    it "overrides supports from false to true" do
      stub_supports(Post, :delete)

      expect(Post.supports?(:delete)).to be true
      expect(Post.unsupported_reason(:delete)).to be nil
      expect(Post.new.supports?(:delete)).to be true
      expect(Post.new.unsupported_reason(:delete)).to be nil
    end

    it "overrides supports (string) from false to true" do
      stub_supports(Post, "delete")

      expect(Post.supports?(:delete)).to be true
      expect(Post.new.supports?(:delete)).to be true
    end

    it "overrides supports references" do
      stub_supports_all_others(Post)
      stub_supports(Post, :delete)

      expect(Post.new.supports?(:delete_ref)).to be true
      expect(Post.new.unsupported_reason(:delete_ref)).to be nil
    end
  end

  context "stub_supports_not" do
    it "starts as true" do
      expect(Post.supports?(:archive)).to be true
    end

    it "overrides supports from true to false" do
      stub_supports_not(Post, :archive, "reasons")

      expect(Post.supports?(:archive)).to be false
      expect(Post.unsupported_reason(:archive)).to eq("reasons")
      expect(Post.new.supports?(:archive)).to be false
      expect(Post.new.unsupported_reason(:archive)).to eq("reasons")
    end

    it "ref starts as true" do
      expect(Post.supports?(:archive_ref)).to be true
    end

    it "overrides supports references" do
      stub_supports_all_others(Post)
      stub_supports_not(Post, :archive, "reasons")

      expect(Post.new.supports?(:archive_ref)).to be false
      expect(Post.new.unsupported_reason(:archive_ref)).to eq("reasons")
    end
  end
end
