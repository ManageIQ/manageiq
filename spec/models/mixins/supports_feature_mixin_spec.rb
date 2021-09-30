RSpec.describe SupportsFeatureMixin do
  before do
    stub_const('Post::Operations::Publishing', Module.new do
      extend ActiveSupport::Concern

      included do
        supports :publish
      end
    end)

    stub_const('Post::Operations', Module.new do
      extend ActiveSupport::Concern
      include Post::Operations::Publishing

      included do
        supports :archive
        supports_not :delete
        supports_not :fake, :reason => 'We keep it real!'
      end
    end)

    stub_const('Post', Class.new do
      include SupportsFeatureMixin
      include Post::Operations

      delegate_supports :author_create, "Author", :create
      delegate_supports :author_delete, "Author", :delete
    end)

    stub_const('SpecialPost::Operations', Module.new do
      extend ActiveSupport::Concern

      included do
        supports :fake do
          unsupported_reason_add(:fake, 'Need more money') unless bribe
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

    stub_const('Post::Author', Class.new do
      include SupportsFeatureMixin
      supports :create
      supports_not :delete, :reason => "Keep them around"
    end)
  end

  context "defines method" do
    it "supports_feature? on the class" do
      expect(Post.respond_to?(:supports_publish?)).to be true
    end

    it "supports_feature? on the instance" do
      expect(Post.new.respond_to?(:supports_publish?)).to be true
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
      expect(Post.supports_publish?).to be true
    end

    it ".supports?(feature) is true" do
      expect(Post.supports?(:publish)).to be true
    end

    it "#supports_feature? is true" do
      expect(Post.new.supports_publish?).to be true
    end

    it "#unsupported_reason(:feature) is nil" do
      expect(Post.new.unsupported_reason(:publish)).to be nil
    end

    it ".unsupported_reason(:feature) is nil" do
      expect(Post.unsupported_reason(:publish)).to be nil
    end
  end

  context "for an unsupported feature" do
    it ".supports_feature? is false" do
      expect(Post.supports_fake?).to be false
    end

    it "#supports_feature? is false" do
      expect(Post.new.supports_fake?).to be false
    end

    it "#unsupported_reason(:feature) returns a reason" do
      expect(Post.new.unsupported_reason(:fake)).to eq "We keep it real!"
    end

    it ".unsupported_reason(:feature) returns a reason" do
      expect(Post.unsupported_reason(:fake)).to eq "We keep it real!"
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
      expect(Post.respond_to?(:supports_archive?)).to be true
    end

    it "defines an instance method" do
      expect(Post.new.respond_to?(:supports_archive?)).to be true
    end
  end

  context "a feature defined on the base class" do
    it "defines supports_feature? on the subclass" do
      expect(SpecialPost.respond_to?(:supports_publish?)).to be true
    end

    it "defines supports_feature? on an instance of the subclass" do
      expect(SpecialPost.new.respond_to?(:supports_publish?)).to be true
    end

    it "can be overriden on the subclass" do
      expect(SpecialPost.supports_fake?).to be true
    end
  end

  context "conditionally supported feature" do
    context "when the condition is met" do
      it "is supported on the class" do
        expect(SpecialPost.supports_fake?).to be true
      end

      it "is supported on the instance" do
        expect(SpecialPost.new(:bribe => true).supports_fake?).to be true
      end

      it "gives no reason on the class" do
        expect(SpecialPost.unsupported_reason(:fake)).to be nil
      end

      it "gives no reason on the instance" do
        expect(SpecialPost.new(:bribe => true).unsupported_reason(:fake)).to be nil
      end
    end

    context "when the condition is not met" do
      it "gives a reason on the instance" do
        special_post = SpecialPost.new
        expect(special_post.supports_fake?).to be false
        expect(special_post.unsupported_reason(:fake)).to eq "Need more money"
      end

      it "gives a reason without calling supports_feature? first" do
        expect(SpecialPost.new.unsupported_reason(:fake)).to eq "Need more money"
      end
    end

    context "when the condition changes on the instance" do
      it "is checks the current condition" do
        special_post = SpecialPost.new
        expect(special_post.supports_fake?).to be false
        expect(special_post.unsupported_reason(:fake)).to eq "Need more money"
        special_post.bribe = true
        expect(special_post.supports_fake?).to be true
        expect(special_post.unsupported_reason(:fake)).to be nil
      end
    end
  end

  context "feature that is implicitly unsupported" do
    it "can be supported by the class" do
      stub_const("NukeablePost", Class.new(SpecialPost) do
        supports :nuke do
          unsupported_reason_add(:nuke, "do not nuke the bribe") if bribe
        end
      end)
      expect(NukeablePost.new(:bribe => true).supports_nuke?).to be false
      expect(NukeablePost.new(:bribe => false).supports_nuke?).to be true
    end
  end

  context "delegate supports" do
    it "supports base implementation" do
      expect(Post::Author.supports?(:create)).to be true # FYI
      expect(Post.supports?(:author_create)).to be true
      expect(Post.new.supports?(:author_create)).to be true
    end

    it "detects non supported base implementation" do
      expect(Post::Author.supports?(:delete)).to be false # FYI
      expect(Post.supports?(:author_delete)).to be false
      expect(Post.unsupported_reason(:author_delete)).to eq("Keep them around")
      expect(Post.new.supports?(:author_delete)).to be false
      expect(Post.new.unsupported_reason(:author_delete)).to eq("Keep them around")
    end

    it "choose the correct child subclass" do
      stub_const('Child::Post', Class.new(Post))

      stub_const('Child::Post::Author', Class.new(Child::Post) do
        include SupportsFeatureMixin
        # supports :create # note: create supports is not inherited
        supports :delete
      end)

      expect(Child::Post::Author.supports?(:create)).to be false # FYI
      expect(Child::Post.supports?(:author_create)).to be false
      expect(Child::Post.new.supports?(:author_create)).to be false

      expect(Child::Post::Author.supports?(:delete)).to be true # FYI
      expect(Child::Post.supports?(:author_delete)).to be true
      expect(Child::Post.new.supports?(:author_delete)).to be true
    end

    it "handles cases where there is no child subclass defined" do
      stub_const('Child::Post', Class.new(Post))

      # Child::Post::Author is not defined, it returns Post::Author in some cases
      expect(Child::Post::Author).to be(Post::Author) # FYI
      expect(Child::Post.supports?(:author_create)).to be false
      expect(Child::Post.unsupported_reason(:author_delete)).to eq("Author not implemented")
      expect(Child::Post.new.supports?(:author_create)).to be false
      expect(Child::Post.new.unsupported_reason(:author_delete)).to eq("Author not implemented")
    end
  end
end
