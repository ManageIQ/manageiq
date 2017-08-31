describe SupportsFeatureMixin do
  before do
    stub_const('Post::Operations::Publishing', Module.new do
      extend ActiveSupport::Concern

      included do
        supports :create
      end
    end)

    stub_const('Post::Operations', Module.new do
      extend ActiveSupport::Concern
      include Post::Operations::Publishing

      included do
        supports :retire
        supports_not :delete
        supports_not :discovery, :reason => 'Your posts are bad'
      end
    end)

    stub_const('Post', Class.new do
      include SupportsFeatureMixin
      include Post::Operations
    end)

    stub_const('SpecialPost::Operations', Module.new do
      extend ActiveSupport::Concern

      included do
        supports :discovery do
          unsupported_reason_add(:discovery, 'Need more money') unless bribe
        end
      end
    end)

    stub_const('SpecialPost', Class.new(Post) do
      include SupportsFeatureMixin
      include SpecialPost::Operations

      attr_accessor :bribe

      def initialize(options = {})
        self.bribe = options[:bribe]
      end
    end)
  end

  context "defines method" do
    it "supports_feature? on the class" do
      expect(Post.respond_to?(:supports_create?)).to be true
    end

    it "supports_feature? on the instance" do
      expect(Post.new.respond_to?(:supports_create?)).to be true
    end

    it "unsupported_reason on the class" do
      expect(Post.respond_to?(:unsupported_reason)).to be true
    end

    it "unsupported_reason on the instance" do
      expect(Post.new.respond_to?(:unsupported_reason)).to be true
    end
  end

  context "for a supported feature" do
    it ".supports_feature? is true" do
      expect(Post.supports_create?).to be true
    end

    it ".supports?(feature) is true" do
      expect(Post.supports?(:create)).to be true
    end

    it "#supports_feature? is true" do
      expect(Post.new.supports_create?).to be true
    end

    it "#unsupported_reason(:feature) is nil" do
      expect(Post.new.unsupported_reason(:create)).to be nil
    end

    it ".unsupported_reason(:feature) is nil" do
      expect(Post.unsupported_reason(:create)).to be nil
    end
  end

  context "for an unsupported feature" do
    it ".supports_feature? is false" do
      expect(Post.supports_discovery?).to be false
    end

    it "#supports_feature? is false" do
      expect(Post.new.supports_discovery?).to be false
    end

    it "#unsupported_reason(:feature) returns a reason" do
      expect(Post.new.unsupported_reason(:discovery)).to eq("Your posts are bad")
    end

    it ".unsupported_reason(:feature) returns a reason" do
      expect(Post.unsupported_reason(:discovery)).to eq("Your posts are bad")
    end
  end

  context "for an unsupported feature without a reason" do
    it ".supports_feature? is false" do
      expect(Post.supports_delete?).to be false
    end

    it "#supports_feature? is false" do
      expect(Post.new.supports_delete?).to be false
    end

    it "#unsupported_reason(:feature) returns some default reason" do
      expect(Post.new.unsupported_reason(:delete)).not_to be_blank
    end

    it ".unsupported_reason(:feature) returns no reason" do
      expect(Post.unsupported_reason(:delete)).not_to be_blank
    end
  end

  context "definition in nested modules" do
    it "defines a class method on the model" do
      expect(Post.respond_to?(:supports_retire?)).to be true
    end

    it "defines an instance method" do
      expect(Post.new.respond_to?(:supports_retire?)).to be true
    end
  end

  context "a feature defined on the base class" do
    it "defines supports_feature? on the subclass" do
      expect(SpecialPost.respond_to?(:supports_create?)).to be true
    end

    it "defines supports_feature? on an instance of the subclass" do
      expect(SpecialPost.new.respond_to?(:supports_create?)).to be true
    end

    it "can be overriden on the subclass" do
      expect(SpecialPost.supports_discovery?).to be true
    end
  end

  context "conditionally supported feature" do
    context "when the condition is met" do
      it "is supported on the class" do
        expect(SpecialPost.supports_discovery?).to be true
      end

      it "is supported on the instance" do
        expect(SpecialPost.new(:bribe => true).supports_discovery?).to be true
      end

      it "gives no reason on the class" do
        expect(SpecialPost.unsupported_reason(:discovery)).to be nil
      end

      it "gives no reason on the instance" do
        expect(SpecialPost.new(:bribe => true).unsupported_reason(:discovery)).to be nil
      end
    end

    context "when the condition is not met" do
      it "gives a reason on the instance" do
        special_post = SpecialPost.new
        expect(special_post.supports_discovery?).to be false
        expect(special_post.unsupported_reason(:discovery)).to eq "Need more money"
      end

      it "gives a reason without calling supports_feature? first" do
        expect(SpecialPost.new.unsupported_reason(:discovery)).to eq "Need more money"
      end
    end

    context "when the condition changes on the instance" do
      it "is checks the current condition" do
        special_post = SpecialPost.new
        expect(special_post.supports_discovery?).to be false
        expect(special_post.unsupported_reason(:discovery)).to eq "Need more money"
        special_post.bribe = true
        expect(special_post.supports_discovery?).to be true
        expect(special_post.unsupported_reason(:discovery)).to be nil
      end
    end
  end

  context "guards against unqueriable features" do
    it "when defining a class with :supports_not" do
      stub_const("MegaPost", Class.new)
      expect do
        class MegaPost
          include SupportsFeatureMixin
          supports_not :mega
        end
      end.to raise_error(SupportsFeatureMixin::UnknownFeatureError)
    end

    it "when defining a class with :supports" do
      stub_const("MegaPost", Class.new)
      expect do
        class MegaPost
          include SupportsFeatureMixin
          supports :mega
        end
      end.to raise_error(SupportsFeatureMixin::UnknownFeatureError)
    end

    it "when querying a feature on the class" do
      expect do
        SpecialPost.supports?('mega')
      end.to raise_error(SupportsFeatureMixin::UnknownFeatureError)
    end

    it "when querying a feature on the instance" do
      expect do
        SpecialPost.new.supports?('mega')
      end.to raise_error(SupportsFeatureMixin::UnknownFeatureError)
    end

    it "when querying a reason on the class" do
      expect do
        SpecialPost.unsupported_reason(:mega)
      end.to raise_error(SupportsFeatureMixin::UnknownFeatureError)
    end

    it "when querying a reason on the instance" do
      expect do
        SpecialPost.new.unsupported_reason(:mega)
      end.to raise_error(SupportsFeatureMixin::UnknownFeatureError)
    end
  end

  context "can be queried for features" do
    it "that are known on the class" do
      expect(Post.feature_known?("discovery")).to be true
    end

    it "that are unknown on the class" do
      expect(Post.feature_known?("lobotomize")).to be false
    end

    it "that are known on the instance" do
      expect(Post.new.feature_known?("discovery")).to be true
    end

    it "that are unknown on the instance" do
      expect(Post.new.feature_known?("lobotomize")).to be false
    end
  end

  context "feature that is implicitly unsupported" do
    it "is unsupported by the class" do
      expect(Post.supports_delete?).to be false
    end

    it "is unsupported by an instance of the class" do
      expect(Post.new.supports_delete?).to be false
    end

    it "can be supported by the class" do
      stub_const("DeleteablePost", Class.new(SpecialPost) do
        supports :delete do
          unsupported_reason_add(:delete, "dont delete the bribe") if bribe
        end
      end)
      expect(DeleteablePost.new(:bribe => true).supports_delete?).to be false
      expect(DeleteablePost.new(:bribe => false).supports_delete?).to be true
    end
  end

  context 'when included to a class a second time via another module which includes the mixin' do
    before do
      stub_const('MyModule', Module.new do
        extend ActiveSupport::Concern
        include SupportsFeatureMixin
      end)

      stub_const('SomePost', Class.new(Post) do
        include MyModule
      end)
    end

    it "doesn't overwrite existing methods" do
      expect(Post.new.supports_create?).to eq(true)
      expect(Post.supports_create?).to eq(true)
      expect(SomePost.new.supports_create?).to eq(true)
      expect(SomePost.supports_create?).to eq(true)
    end
  end

  context 'used in a module WITHOUT using `included` hook' do
    before do
      stub_const('MyModule', Module.new do
        include SupportsFeatureMixin
        supports_not :create     # supported in base class Post
        supports :discovery do   # unsupported in base class Post
          unsupported_reason_add(:discovery, "Your Post is bad!")
        end
      end)

      stub_const('SomePost', Class.new(Post) do
        include MyModule
      end)
    end

    it "does not affect undefined features" do
      expect(SomePost.new.supports_delete?).to be false
      expect(SomePost.supports_delete?).to be false
    end

    it "overrides features defined on the class with those in the module" do
      expect(SomePost.new.supports_create?).to be false
      expect(SomePost.supports_create?).to be false

      expect(SomePost.supports_discovery?).to be true
      expect(SomePost.new.supports_discovery?).to be false
      expect(SomePost.new.unsupported_reason(:discovery)).to eq('Your Post is bad!')
    end
  end
end
