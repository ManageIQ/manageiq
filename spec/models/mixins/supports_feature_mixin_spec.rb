describe SupportsFeatureMixin do
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
        supports_not :fake, "We keep it real!"
      end
    end)

    stub_const('Post', Class.new do
      include SupportsFeatureMixin
      include Post::Operations
    end)

    stub_const('SpecialPost::Operations', Module.new do
      extend ActiveSupport::Concern

      included do
        supports :fake do |post|
          post.unsupported[:fake] = "Need more money" unless post.bribe
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
      expect(Post.respond_to?(:supports_publish?)).to be true
    end

    it "supports_feature? on the instance" do
      expect(Post.new.respond_to?(:supports_publish?)).to be true
    end

    it "unsupported on the class" do
      expect(Post.respond_to?(:unsupported)).to be true
    end

    it "unsupported on the instance" do
      expect(Post.new.respond_to?(:unsupported)).to be true
    end
  end

  context "for a supported feature" do
    it ".supports_feature? is true" do
      expect(Post.supports_publish?).to be true
    end

    it "#supports_feature? is true" do
      expect(Post.new.supports_publish?).to be true
    end

    it "#unsupported[:feature] is nil" do
      expect(Post.new.unsupported[:publish]).to be nil
    end

    it ".unsupported[:feature] is nil" do
      expect(Post.unsupported[:publish]).to be nil
    end
  end

  context "for an unsupported feature" do
    it ".supports_feature? is false" do
      expect(Post.supports_fake?).to be false
    end

    it "#supports_feature? is true" do
      expect(Post.new.supports_fake?).to be false
    end

    it "#unsupported[:feature] returns a reason" do
      expect(Post.new.unsupported[:fake]).to eq "We keep it real!"
    end

    it ".unsupported[:feature] returns a reason" do
      expect(Post.unsupported[:fake]).to eq "We keep it real!"
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
        expect(SpecialPost.unsupported[:fake]).to be nil
      end

      it "gives no reason on the instance" do
        expect(SpecialPost.new(:bribe => true).unsupported[:fake]).to be nil
      end
    end

    context "when the condition is not met" do
      it "gives a reason on the instance" do
        special_post = SpecialPost.new
        expect(special_post.supports_fake?).to be false
        expect(special_post.unsupported[:fake]).to eq "Need more money"
      end

      it "gives a reason without calling supports_feature? first" do
        expect(SpecialPost.new.unsupported[:fake]).to eq "Need more money"
      end
    end

    context "when the condition changes on the instance" do
      it "is checks the current condition" do
        special_post = SpecialPost.new
        expect(special_post.supports_fake?).to be false
        expect(special_post.unsupported[:fake]).to eq "Need more money"
        special_post.bribe = true
        expect(special_post.supports_fake?).to be true
        expect(special_post.unsupported[:fake]).to be nil
      end
    end
  end
end
