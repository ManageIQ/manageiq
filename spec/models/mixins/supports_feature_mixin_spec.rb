RSpec.describe SupportsFeatureMixin do
  after do
    if defined?(@defined_parent_classes)
      @defined_parent_classes.each { |klass, children| cleanup_subclass(klass, children) }
    end
  end

  let(:test_class) do
    Class.new do
      attr_accessor :attr1

      include SupportsFeatureMixin

      # no need to make this dynamic
      def initialize(values = {})
        @attr1 = values[:attr1]
      end

      # usually a name like Post::Operations
      include(Module.new do
        extend ActiveSupport::Concern

        included do
          supports :module_accept
        end
      end)

      supports :std_accept
      supports_not :std_denial, :reason => "not available"
      supports(:dynamic_feature) { "dynamically unsupported" unless attr1 }
    end
  end

  let(:test_inst) { test_class.new }

  describe ".supports?" do
    it "handles base supports" do
      expect(test_class.supports?(:std_accept)).to be_truthy
      expect(test_class.supports?(:module_accept)).to be_truthy
      expect(test_class.supports?(:std_denial)).to be_falsey
    end

    it "denies when no denial reason is given" do
      test_class.supports_not :denial_no_reason

      expect(test_class.supports?(:denial_no_reason)).to be_falsey
    end

    it "supports dynamic features for classes (note: logic is not called)" do
      expect(test_class.supports?(:dynamic_feature)).to be_truthy
    end

    it "handles unknown supports" do
      expect(test_class.supports?(:denial_unknown_feature)).to be_falsey
    end

    context "with child class" do
      it "overrides to deny" do
        child_class = define_model(nil, test_class, :std_accept => false, :module_accept => false, :dynamic_feature => false)
        expect(child_class.supports?(:std_accept)).to be_falsey
        expect(child_class.supports?(:module_accept)).to be_falsey
        expect(child_class.supports?(:dynamic_feature)).to be_falsey
      end

      it "overrides to supports" do
        child_class = define_model(nil, test_class, :std_denial => true)
        expect(child_class.supports?(:std_denial)).to be_truthy
      end

      it "overriding to supports with dynamic" do
        child_class = define_model(nil, test_class, :std_denial => :dynamic)

        expect(child_class.supports?(:std_denial)).to be_truthy
      end
    end
  end

  describe '#supports?' do
    it "handles base supports" do
      expect(test_inst.supports?(:std_accept)).to be_truthy
      expect(test_inst.supports?(:module_accept)).to be_truthy
      expect(test_inst.supports?(:std_denial)).to be_falsey
    end

    it "denies with no reason given" do
      test_class.supports_not :denial_no_reason
      expect(test_inst.supports?(:denial_no_reason)).to be_falsey
    end

    it "handles unknown supports" do
      expect(test_inst.supports?(:denial_unknown_feature)).to be_falsey
    end

    it "denies dynamic attrs" do
      test_inst = test_class.new(:attr1 => false)

      expect(test_inst.supports?(:dynamic_feature)).to be_falsey
    end

    it "supports dynamic attrs" do
      test_inst = test_class.new(:attr1 => true)

      expect(test_inst.supports?(:dynamic_feature)).to be_truthy
    end

    it "denies implicit dynamic attrs" do
      test_class.supports(:implicit_feature) { "dynamically unsupported" unless attr1 }
      test_inst = test_class.new(:attr1 => false)

      expect(test_inst.supports?(:implicit_feature)).to be_falsey
    end

    it "supports implicit dynamic attrs" do
      test_class.supports(:implicit_feature) { "dynamically unsupported" unless attr1 }
      test_inst = test_class.new(:attr1 => true)

      expect(test_inst.supports?(:implicit_feature)).to be_truthy
    end

    it "overrides to deny from child class" do
      child_class = define_model(nil, test_class, :std_accept => false, :module_accept => false, :dynamic_feature => false)
      test_inst = child_class.new(:attr1 => true)

      expect(test_inst.supports?(:std_accept)).to be_falsey
      expect(test_inst.supports?(:module_accept)).to be_falsey
      expect(test_inst.supports?(:dynamic_feature)).to be_falsey
    end

    it "overrides to supports with child class" do
      child_class = define_model(nil, test_class, :std_denial => true, :dynamic_feature => true)

      test_inst = child_class.new(:attr1 => false)

      expect(test_inst.supports?(:std_denial)).to be_truthy
      expect(test_inst.supports?(:dynamic_feature)).to be_truthy
    end

    it "instance redirects work properly" do
      test_class.instance_eval do
        supports(:dynamic_attr)      { unsupported_reason(:dynamic_operation) }
        supports(:dynamic_operation) { "unsupported" }
      end

      child_class = define_model(nil, test_class)
      child_class.instance_eval do
        supports(:dynamic_operation) { nil }
      end

      # parent
      expect(test_class.new.supports?(:dynamic_operation)).to be_falsey
      expect(test_class.new.supports?(:dynamic_attr)).to be_falsey

      # child
      expect(child_class.new.supports?(:dynamic_operation)).to be_truthy
      expect(child_class.new.supports?(:dynamic_attr)).to be_truthy
      expect(child_class.new.unsupported_reason(:dynamic_attr)).to eq(nil)
    end

    context "with dynamic child class" do
      let(:child_class) do
        define_model(
          nil, test_class,
          :std_denial      => :dynamic,
          :std_accept      => :dynamic,
          :module_accept   => :dynamic,
          :dynamic_feature => :dynamic
        )
      end

      it "overriding to supports with dynamic positive logic" do
        test_inst = child_class.new(:attr1 => true)

        expect(test_inst.supports?(:std_accept)).to be_truthy
        expect(test_inst.supports?(:module_accept)).to be_truthy
        expect(test_inst.supports?(:std_denial)).to be_truthy
        expect(test_inst.supports?(:dynamic_feature)).to be_truthy

        test_inst.attr1 = false

        expect(test_inst.supports?(:std_accept)).to be_falsey
        expect(test_inst.supports?(:module_accept)).to be_falsey
        expect(test_inst.supports?(:std_denial)).to be_falsey
        expect(test_inst.supports?(:dynamic_feature)).to be_falsey
      end
    end
  end

  describe '.unsupported_reason' do
    it "handles supports" do
      expect(test_class.unsupported_reason(:std_accept)).to be_nil
      expect(test_class.unsupported_reason(:module_accept)).to be_nil
      expect(test_class.unsupported_reason(:std_denial)).to eq "not available"
    end

    it "defaults denial reason when given no reason" do
      test_class.supports_not :denial_no_reason
      expect(test_class.unsupported_reason(:denial_no_reason)).to eq("Feature not available/supported")
    end

    it "defaults denial reason for unknown feature" do
      expect(test_class.unsupported_reason(:denial_unknown_feature)).to eq("Feature not available/supported")
    end
  end

  describe '#unsupported_reason' do
    it "handles supports" do
      expect(test_inst.unsupported_reason(:std_accept)).to be_nil
      expect(test_inst.unsupported_reason(:module_accept)).to be_nil
      expect(test_inst.unsupported_reason(:std_denial)).to eq "not available"
    end

    it "gives defaults denial reason" do
      test_class.supports_not :denial_no_reason
      expect(test_inst.unsupported_reason(:denial_no_reason)).to eq("Feature not available/supported")
    end

    it "defaults denial reason for unknown feature" do
      expect(test_inst.unsupported_reason(:denial_unknown_feature)).to eq("Feature not available/supported")
    end

    it "gives reason when dynamic feature" do
      test_inst = test_class.new(:attr1 => false)

      expect(test_inst.unsupported_reason(:dynamic_feature)).to eq("dynamically unsupported")
    end

    it "changes reasons when dynamic feature logic changes" do
      test_inst = test_class.new(:attr1 => false)

      expect(test_inst.unsupported_reason(:dynamic_feature)).to eq("dynamically unsupported")

      test_inst.attr1 = true
      expect(test_inst.supports?(:dynamic_feature)).to be_truthy # this recalculates the reason

      expect(test_inst.unsupported_reason(:dynamic_feature)).to be_nil
    end

    it "gives reason when implicit dynamic attrs" do
      test_class.supports(:implicit_feature) { "dynamically unsupported" unless attr1 }
      test_inst = test_class.new(:attr1 => false)

      expect(test_inst.unsupported_reason(:implicit_feature)).to eq("dynamically unsupported")
    end

    it "gives reason when chained to a denail with a default reason" do
      test_class.supports_not :denial_no_reason
      test_class.supports(:denial_chained) { unsupported_reason(:denial_no_reason) }

      expect(test_inst.unsupported_reason(:denial_chained)).to eq("Feature not available/supported")
    end

    it "gives reason when chained to a denail with a default reason (checking supported)" do
      test_class.supports_not :denial_no_reason
      test_class.supports(:denial_chained) { unsupported_reason(:denial_no_reason) unless supports?(:denial_no_reason) }

      expect(test_inst.unsupported_reason(:denial_chained)).to eq("Feature not available/supported")
    end

    it "gives no reason when chained to an attribute with success" do
      test_class.supports(:std_chained) { unsupported_reason(:std_accept) }

      expect(test_inst.unsupported_reason(:std_chained)).to eq(nil)
    end

    it "gives no reason when chained to an attribute with success (checking supported)" do
      test_class.supports(:std_chained) { unsupported_reason(:std_accept) unless supports?(:std_accept) }

      expect(test_inst.unsupported_reason(:std_chained)).to eq(nil)
    end
  end

  describe ".subclasses_supporting" do
    it 'detect' do
      define_subclass("ProviderA", model, :fake => true)
      define_subclass("ProviderB", model, :publish => false, :delete => true, :fake => true)

      expect(model.subclasses_supporting(:publish).map(&:name)).to eq(%w[ProviderA::Model])
      expect(model.subclasses_supporting(:delete).map(&:name)).to eq(%w[ProviderB::Model])
      expect(model.subclasses_supporting(:fake).map(&:name)).to match_array(%w[ProviderA::Model ProviderB::Model])
    end
  end

  describe ".provider_classes_supporting" do
    it 'detects' do
      define_subclass("ProviderA", model, :fake => true)
      define_subclass("ProviderB", model, :publish => false, :delete => true, :fake => true)

      expect(model.provider_classes_supporting(:publish).map(&:name)).to eq(%w[ProviderA])
      expect(model.provider_classes_supporting(:delete).map(&:name)).to eq(%w[ProviderB])
      expect(model.provider_classes_supporting(:fake).map(&:name)).to match_array(%w[ProviderA ProviderB])
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
    child = Class.new(parent) do
      include SupportsFeatureMixin unless parent.respond_to?(:supports?)

      yield(self) if block_given?
      supports_values.each do |feature, value|
        case value
        when true
          supports feature
        when false
          supports_not feature
        when String
          supports_not feature, :reason => value
        when :dynamic
          supports(feature) { "dynamically unsupported" unless attr1 }
        else
          raise "trouble defining #{feature} with #{value.class.name}"
        end
      end
    end

    stub_const(class_name, child) if class_name
    # remember what is subclasses so we can clean up the descendant cache
    ((@defined_parent_classes ||= {})[parent] ||= []) << child
    child
  end
end
