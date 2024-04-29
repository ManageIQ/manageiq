#
# Including this in a model gives you a DSL to make features supported or not
#
#   class Post
#     include SupportsFeatureMixin
#     supports :publish
#     supports_not :fake, :reason => 'We keep it real'
#     supports :archive do
#       'It is too good' if featured?
#     end
#   end
#
# To make a feature conditionally supported, pass a block to the +supports+ method.
# The block is evaluated in the context of the instance.
# If a feature is not supported, return a string for the reason. A nil means it is supported
# Alternatively, calling the private method +unsupported_reason_add+ with the feature
# and a reason, marks the feature as unsupported, and the reason will be
# accessible through
#
#   instance.unsupported_reason(:feature)
#
#   Post.supports?(:publish)                     # => true
#   Post.new.supports?(:publish)                 # => true
#   Post.supports?(:archive)                     # => true
#   Post.new(featured: true).supports?(:archive) # => false
#
# To get a reason why a feature is unsupported use the +unsupported_reason+ method
#
#   Post.unsupported_reason(:publish)                     # => "Feature not supported"
#   Post.unsupported_reason(:fake)                        # => "We keep it real"
#   Post.new(featured: true).unsupported_reason(:archive) # => "It is too good"
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
module SupportsFeatureMixin
  extend ActiveSupport::Concern

  # Whenever this mixin is included we define all features as unsupported by default.
  # This way we can query for every feature
  included do
    private_class_method :unsupported
    private_class_method :unsupported_reason_add
    class_attribute :supports_features, :instance_writer => false, :default => {}
  end

  def self.default_supports_reason
    _("Feature not available/supported")
  end

  # query instance for the reason why the feature is unsupported
  def unsupported_reason(feature)
    feature = feature.to_sym
    supports?(feature) unless unsupported.key?(feature)
    unsupported[feature]
  end

  # query the instance if the feature is supported or not
  def supports?(feature)
    self.class.check_supports(feature.to_sym, :instance => self)
  end

  private

  # used inside a +supports+ block to add a reason why the feature is not supported
  # just adding a reason will make the feature unsupported
  def unsupported_reason_add(feature, reason)
    feature = feature.to_sym
    unsupported[feature] = reason
  end

  def unsupported
    @unsupported ||= {}
  end

  class_methods do
    # This is the DSL used a class level to define what is supported
    def supports(feature, &block)
      self.supports_features = supports_features.merge(feature.to_sym => block || true)
    end

    # supports_not does not take a block, because its never supported
    # and not conditionally supported
    def supports_not(feature, reason: nil)
      self.supports_features = supports_features.merge(feature.to_sym => reason.presence || false)
    end

    # query the class if the feature is supported or not
    def supports?(feature)
      check_supports(feature.to_sym, :instance => self)
    end

    def check_supports(feature, instance:)
      instance.send(:unsupported).delete(feature)

      # undeclared features are not supported
      value = supports_features[feature.to_sym]

      if value.respond_to?(:call)
        begin
          # for class level supports, blocks are not evaluated and assumed to be true
          result = instance.instance_eval(&value) unless instance.kind_of?(Class)
          # if no errors yet but result was an error message
          # then add the error
          if !instance.send(:unsupported).key?(feature) && result.kind_of?(String)
            instance.send(:unsupported_reason_add, feature, result)
          end
        rescue => e
          _log.log_backtrace(e)
          instance.send(:unsupported_reason_add, feature, "Internal Error: #{e.message}")
        end
      elsif value != true
        instance.send(:unsupported_reason_add, feature, value || SupportsFeatureMixin.default_supports_reason)
      end
      !instance.send(:unsupported).key?(feature)
    end

    # all subclasses that are considered for supporting features
    def supported_subclasses
      descendants
    end

    def subclasses_supporting(feature)
      supported_subclasses.select { |subclass| subclass.supports?(feature) }
    end

    def types_supporting(feature)
      subclasses_supporting(feature).map(&:name)
    end

    # Provider classes that support this feature
    def provider_classes_supporting(feature)
      subclasses_supporting(feature).map(&:module_parent)
    end

    # scope to query all those classes that support a particular feature
    def supporting(feature)
      # First find all instances where the class supports <feature> then select instances
      # which also support <feature> (e.g. the supports block does not add an unsupported_reason)
      where(:type => types_supporting(feature)).select { |instance| instance.supports?(feature) }
    end

    # Providers that support this feature
    #
    # example:
    #   Host.providers_supporting(feature) # => [Ems]
    def providers_supporting(feature)
      ExtManagementSystem.where(:type => provider_classes_supporting(feature).map(&:name))
    end

    # query the class for the reason why something is unsupported
    def unsupported_reason(feature)
      feature = feature.to_sym
      supports?(feature) unless unsupported.key?(feature)
      unsupported[feature]
    end

    def unsupported
      # This is a class variable and it might be modified during runtime
      # because we do not eager load all classes at boot time, so it needs to be thread safe
      @unsupported ||= Concurrent::Hash.new
    end

    # use this for making a class not support a feature
    def unsupported_reason_add(feature, reason)
      unsupported[feature.to_sym] = reason
    end
  end
end
