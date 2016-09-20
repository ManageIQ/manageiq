module SupportsFeatureMixin
  #
  # Including this in a model gives you a DSL to make features supported or not
  #
  #   class Post
  #     include SupportsFeatureMixin
  #     supports :publish
  #     supports_not :fake, :reason => 'We keep it real'
  #     supports :archive do
  #       unsupported_reason_add(:archive, 'Its too good') if featured?
  #     end
  #   end
  #
  # To make a feature conditionally supported, pass a block to the +supports+ method.
  # The block is evaluated in the context of the instance.
  # If you call the private method +unsupported_reason_add+ with the feature
  # and a reason, then the feature will be unsupported and the reason will be
  # accessible through
  #
  #   instance.unsupported_reason(:feature)
  #
  # The above allows you to call +supports_feature?+ or +supports?(feature) :methods
  # on the Class and Instance
  #
  #   Post.supports_publish?                       # => true
  #   Post.supports?(:publish)                     # => true
  #   Post.new.supports_publish?                   # => true
  #   Post.supports_fake?                          # => false
  #   Post.supports_archive?                       # => true
  #   Post.new(featured: true).supports_archive?   # => false
  #
  # To get a reason why a feature is unsupported use the +unsupported_reason+ method
  #
  #   Post.unsupported_reason(:publish)                     # => "Feature not supported"
  #   Post.unsupported_reason(:fake)                        # => "We keep it real"
  #   Post.new(featured: true).unsupported_reason(:archive) # => "Its too good"
  #
  # To query for known features you can ask the class or the instance via +feature_known?+
  #
  #   Post.feature_known?('fake')     # => true
  #   Post.new.feature_known?(:fake)  # => true
  #   Post.new.feature_known?(:alert) # => false
  #
  # If you include this concern in a Module that gets included by the Model
  # you have to extend that model with +ActiveSupport::Concern+ and wrap the
  # +supports+ calls in an +included+ block. This is also true for modules in between!
  #
  #   module Operations
  #     extend ActiveSupport::Concern
  #     module Power
  #       extend ActiveSupport::Concern
  #       included do
  #         supports :operation
  #       end
  #     end
  #   end
  #
  extend ActiveSupport::Concern

  QUERYABLE_FEATURES = {
    :associate_floating_ip        => 'Associate a Floating IP',
    :control                      => 'Basic control operations', # FIXME: this is just a internal helper and should be refactored
    :cloud_tenant_mapping         => 'CloudTenant mapping',
    :backup_create                => 'CloudVolume backup creation',
    :backup_restore               => 'CloudVolume backup restore',
    :cinder_service               => 'Cinder storage service',
    :swift_service                => 'Swift storage service',
    :delete                       => 'Deletion',
    :disassociate_floating_ip     => 'Disassociate a Floating IP',
    :discovery                    => 'Discovery of Managers for a Provider',
    :evacuate                     => 'Evacuation',
    :events                       => 'Query for events',
    :launch_cockpit               => 'Launch Cockpit UI',
    :live_migrate                 => 'Live Migration',
    :migrate                      => 'Migration',
    :provisioning                 => 'Provisioning',
    :reboot_guest                 => 'Reboot Guest Operation',
    :reconfigure                  => 'Reconfiguration',
    :refresh_new_target           => 'Refresh non-existing record',
    :regions                      => 'Regions of a Provider',
    :resize                       => 'Resizing',
    :retire                       => 'Retirement',
    :smartstate_analysis          => 'Smartstate Analaysis',
    :terminate                => 'Terminate a VM'
  }.freeze

  included do
    QUERYABLE_FEATURES.keys.each do |feature|
      method_name = "supports_#{feature}?"

      # defines the method on the instance
      define_method(method_name) do
        supports?(feature)
      end

      # defines the method on the class
      define_singleton_method(method_name) do
        supports?(feature)
      end
    end
  end

  class UnknownFeatureError < StandardError; end

  class FeatureDefinition
    def initialize(supported: false, block: nil, unsupported_reason: nil)
      @supported = supported
      @block = block
      @unsupported_reason = unsupported_reason
    end

    def supported?
      @supported
    end

    def unsupported_reason
      SupportsFeatureMixin.reason_or_default(@unsupported_reason) unless supported?
    end

    def block
      @block
    end
  end

  def self.guard_queryable_feature(feature)
    unless QUERYABLE_FEATURES.key?(feature.to_sym)
      raise UnknownFeatureError, "Feature ':#{feature}' is unknown to SupportsFeatureMixin."
    end
  end

  def self.reason_or_default(reason = nil)
    reason.present? ? reason : _("Feature not available/supported")
  end

  # query instance for the reason why the feature is unsupported
  def unsupported_reason(feature)
    SupportsFeatureMixin.guard_queryable_feature(feature)
    feature = feature.to_sym
    supports?(feature) unless unsupported.key?(feature)
    unsupported[feature]
  end

  # query the instance if the feature is supported or not
  def supports?(feature)
    SupportsFeatureMixin.guard_queryable_feature(feature)

    feature = feature.to_sym
    feature_definition = self.class.feature_definition_for(feature)
    if feature_definition.supported?
      unsupported.delete(feature)
      if feature_definition.block
        instance_eval(&feature_definition.block)
      end
    else
      unsupported_reason_add(feature, feature_definition.unsupported_reason)
    end
    !unsupported.key?(feature)
  end

  # query the instance if a feature is generally known
  def feature_known?(feature)
    self.class.feature_known?(feature)
  end

  private

  # used inside a +supports+ block to add a reason why the feature is not supported
  # just adding a reason will make the feature unsupported
  def unsupported_reason_add(feature, reason = nil)
    SupportsFeatureMixin.guard_queryable_feature(feature)
    feature = feature.to_sym
    unsupported[feature] = SupportsFeatureMixin.reason_or_default(reason)
  end

  def unsupported
    @unsupported ||= {}
  end

  class_methods do
    # This is the DSL used a class level to define what is supported
    def supports(feature, &block)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      supported_feature_definitions[feature.to_sym] = FeatureDefinition.new(supported: true, block: block)
    end

    # supports_not does not take a block, because its never supported
    # and not conditionally supported
    def supports_not(feature, reason: nil)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      supported_feature_definitions[feature.to_sym] = FeatureDefinition.new(unsupported_reason: reason)
    end

    # query the class if the feature is supported or not
    def supports?(feature)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      feature_definition_for(feature).supported?
    end

    # query the class for the reason why something is unsupported
    def unsupported_reason(feature)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      feature_definition_for(feature).unsupported_reason
    end

    # query the class if a feature is generally known
    def feature_known?(feature)
      SupportsFeatureMixin::QUERYABLE_FEATURES.key?(feature.to_sym)
    end

    def feature_definition_for(feature)
      feature = feature.to_sym
      feature_definition = nil
      ancestors.detect do |ancestor|
        feature_definition = ancestor.try(:supported_feature_definition, feature)
      end
      feature_definition || FeatureDefinition.new
    end

    def supported_feature_definition(feature)
      supported_feature_definitions[feature]
    end

    private

    def supported_feature_definitions
      @supported_feature_definitions ||= Concurrent::Hash.new
    end
  end
end
