RSpec.describe SupportsFeatureMixin do
  before { define_post }

  after do
    if defined?(@defined_parent_classes)
      @defined_parent_classes.each { |klass, children| cleanup_subclass(klass, children) }
    end
  end

  def define_post
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
    end)
  end

  def define_special_post
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
    before { define_special_post }
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
    before { define_special_post }
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
    before { define_special_post }
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

  describe ".subclasses_supporting" do
    it 'detect' do
      define_subclass("ProviderA", Post, :fake => true)
      define_subclass("ProviderB", Post, :publish => false, :delete => true, :fake => true)

      expect(Post.subclasses_supporting(:publish).map(&:name)).to eq(%w[ProviderA::Post])
      expect(Post.subclasses_supporting(:delete).map(&:name)).to eq(%w[ProviderB::Post])
      expect(Post.subclasses_supporting(:fake).map(&:name)).to match_array(%w[ProviderA::Post ProviderB::Post])
    end
  end

  describe "provider_classes_supporting" do
    it 'detects' do
      define_subclass("ProviderA", Post, :fake => true)
      define_subclass("ProviderB", Post, :publish => false, :delete => true, :fake => true)

      expect(Post.provider_classes_supporting(:publish).map(&:name)).to eq(%w[ProviderA])
      expect(Post.provider_classes_supporting(:delete).map(&:name)).to eq(%w[ProviderB])
      expect(Post.provider_classes_supporting(:fake).map(&:name)).to match_array(%w[ProviderA ProviderB])
    end
  end

  let(:model) do
    define_model("Model", ActiveRecord::Base,
                 :publish => true,
                 :archive => true,
                 :delete  => false,
                 :fake    => 'We keep it real!')
  end

  describe ".supporting" do
    it 'detect' do
      ca = define_subclass("ProviderA", model, :fake => true)
      cb = define_subclass("ProviderB", model, :publish => false, :delete => true, :fake => true)
      define_subclass("ProviderC", model, :publish => false, :delete => true, :fake => true)

      ca.create(:name => "a1")
      ca.create(:name => "a2")
      cb.create(:name => "b1")

      expect(model.supporting(:publish).map(&:name)).to match_array(%w[a1 a2])
      expect(model.supporting(:delete).map(&:name)).to eq(%w[b1])
      expect(model.supporting(:fake).map(&:name)).to match_array(%w[a1 a2 b1])
    end
  end

  describe ".providers_supporting" do
    it 'detect' do
      providera = define_subclass("ProviderA", ExtManagementSystem)
      providerb = define_subclass("ProviderB", ExtManagementSystem)
      providerc = define_subclass("ProviderC", ExtManagementSystem)

      define_subclass(providera.name, model, :fake => true)
      define_subclass(providerb.name, model, :publish => false, :delete => true, :fake => true)
      define_subclass(providerc.name, model, :publish => false, :delete => true, :fake => true)

      FactoryBot.create(:ext_management_system, :type => providera.name, :name => "a1")
      FactoryBot.create(:ext_management_system, :type => providera.name, :name => "a2")
      FactoryBot.create(:ext_management_system, :type => providerb.name, :name => "b1")

      expect(model.providers_supporting(:publish).map(&:name)).to match_array(%w[a1 a2])
      expect(model.providers_supporting(:delete).map(&:name)).to eq(%w[b1])
      expect(model.providers_supporting(:fake).map(&:name)).to match_array(%w[a1 a2 b1])
    end
  end

  private

  def define_model(class_name, parent, supporting_values = {})
    define_supporting_class(class_name, parent, supporting_values) do |r|
      r.table_name = "vms" if parent.ancestors.include?(ActiveRecord::Base)
      yield(r) if block_given?
    end
  end

  def define_subclass(module_name, parent, supports_values = {})
    define_supporting_class("#{module_name}::#{parent.name}", parent, supports_values)
  end

  # these descendants are stored in a cache in active support
  # this cleans out those values so future runs do not have bogus classes
  # this causes sporadic test failures.
  def cleanup_subclass(parent, children)
    tracker = ActiveSupport::DescendantsTracker.class_variable_get(:@@direct_descendants)[parent]
    tracker&.reject! { |child| children.include?(child) }
  end

  def define_supporting_class(class_name, parent, supports_values = {})
    child = stub_const(class_name, Class.new(parent) do
      include SupportsFeatureMixin

      yield(self) if block_given?
      supports_values.each do |feature, value|
        case value
        when true
          supports feature
        when false
          supports_not feature
        when String
          supports_not feature, :reason => value
        when Callable
          supports(feature, &value)
        else
          raise "trouble defining #{feature} with #{value.class.name}"
        end
      end
    end)
    # remember what is subclasses so we can clean up the descendant cache
    ((@defined_parent_classes ||= {})[parent] ||= []) << child
    child
  end
end
