RSpec.describe 'SupportsHelper' do
  include Spec::Support::SupportsHelper

  before do
    stub_const('Post', Class.new do
      include SupportsFeatureMixin
      supports :archive
      supports_not :delete
    end)
  end

  context "stub_supports" do
    it "overrides supports from false to true" do
      expect(Post.supports?(:delete)).to be false

      stub_supports(Post, :delete)

      expect(Post.supports?(:delete)).to be true
      expect(Post.new.supports?(:delete)).to be true
    end
  end

  context "stub_supports_not" do
    it "overrides supports from true to false" do
      expect(Post.supports?(:archive)).to be true

      stub_supports_not(Post, :archive, "reasons")

      expect(Post.supports?(:archive)).to be false
      expect(Post.unsupported_reason(:archive)).to eq("reasons")
      expect(Post.new.supports?(:archive)).to be false
      expect(Post.new.unsupported_reason(:archive)).to eq("reasons")
    end
  end
end
