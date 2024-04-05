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
# The reason will be accessible through
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
    class_attribute :supports_features, :instance_writer => false, :instance_reader => false, :default => {}
  end

  def self.default_supports_reason
    _("Feature not available/supported")
  end

  # query instance for the reason why the feature is unsupported
  def unsupported_reason(feature)
    self.class.unsupported_reason(feature, :instance => self)
  end

  # query the instance if the feature is supported or not
  def supports?(feature)
    !unsupported_reason(feature)
  end

  private

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

    def supports?(feature)
      !unsupported_reason(feature)
    end

    # query the class if the feature is supported or not
    def unsupported_reason(feature, instance: self)
      # undeclared features are not supported
      value = supports_features[feature.to_sym]
      if value.respond_to?(:call)
        begin
          # for class level supports, blocks are not evaluated and assumed to be true
          result = instance.instance_eval(&value) unless instance.kind_of?(Class)
          result if result.kind_of?(String)
        rescue => e
          _log.log_backtrace(e)
          "Internal Error: #{e.message}"
        end
      elsif value != true
        value || SupportsFeatureMixin.default_supports_reason
      end
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
  end
end
