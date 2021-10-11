#
# Including this in a model gives you a DSL to make features supported or not
#
#   class Post
#     include SupportsFeatureMixin
#     supports :publish
#     supports_not :fake, :reason => 'We keep it real'
#     supports :archive do
#       unsupported_reason_add(:archive, 'It is too good') if featured?
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

  COMMON_FEATURES = %i[create delete destroy refresh_ems update].freeze

  # Whenever this mixin is included we define all features as unsupported by default.
  # This way we can query for every feature
  included do
    COMMON_FEATURES.each do |feature|
      supports_not(feature)
    end

    private_class_method :unsupported
    private_class_method :unsupported_reason_add
    private_class_method :define_supports_feature_methods
  end

  def self.reason_or_default(reason)
    reason.present? ? reason : _("Feature not available/supported")
  end

  # query instance for the reason why the feature is unsupported
  def unsupported_reason(feature)
    feature = feature.to_sym
    public_send("supports_#{feature}?") unless unsupported.key?(feature)
    unsupported[feature]
  end

  # query the instance if the feature is supported or not
  def supports?(feature)
    public_send("supports_#{feature}?")
  end

  # query the instance if a feature is generally known
  def feature_known?(feature)
    self.class.feature_known?(feature)
  end

  private

  # used inside a +supports+ block to add a reason why the feature is not supported
  # just adding a reason will make the feature unsupported
  def unsupported_reason_add(feature, reason = nil)
    feature = feature.to_sym
    unsupported[feature] = SupportsFeatureMixin.reason_or_default(reason)
  end

  def unsupported
    @unsupported ||= {}
  end

  class_methods do
    # This is the DSL used a class level to define what is supported
    def supports(feature, &block)
      define_supports_feature_methods(feature, &block)
    end

    # delegate to a child class whether a feature is supported
    # Author => Author::Post
    # will only delegate to a class level supports
    def delegate_supports(feature, target_name, target_feature)
      method_name = "supports_#{feature}?"
      feature = feature.to_sym
      target_feature = target_feature.to_sym

      silence_warnings do
        define_method(method_name) do
          unsupported.delete(feature)
          target = self.class.const_get(target_name, false)
          is_supported = target.supports?(target_feature)
          unsupported_reason_add(feature, target.unsupported_reason(target_feature)) unless is_supported
          !unsupported.key?(feature)
        rescue NameError
          unsupported_reason_add(feature, "#{target_name} not implemented")
          false
        end

        define_singleton_method(method_name) do
          unsupported.delete(feature)
          target = const_get(target_name, false)
          is_supported = target.supports?(target_feature)
          unsupported_reason_add(feature, target.unsupported_reason(target_feature)) unless is_supported
          !unsupported.key?(feature)
        rescue NameError
          unsupported_reason_add(feature, "#{target_name} not implemented")
          false
        end
      end
    end
    # supports_not does not take a block, because its never supported
    # and not conditionally supported
    def supports_not(feature, reason: nil)
      define_supports_feature_methods(feature, :is_supported => false, :reason => reason)
    end

    # query the class if the feature is supported or not
    def supports?(feature)
      public_send("supports_#{feature}?")
    end

    # query the class for the reason why something is unsupported
    def unsupported_reason(feature)
      feature = feature.to_sym
      public_send("supports_#{feature}?") unless unsupported.key?(feature)
      unsupported[feature]
    end

    def unsupported
      # This is a class variable and it might be modified during runtime
      # because we do not eager load all classes at boot time, so it needs to be thread safe
      @unsupported ||= Concurrent::Hash.new
    end

    # use this for making a class not support a feature
    def unsupported_reason_add(feature, reason = nil)
      feature = feature.to_sym
      unsupported[feature] = SupportsFeatureMixin.reason_or_default(reason)
    end

    def define_supports_feature_methods(feature, is_supported: true, reason: nil, &block)
      method_name = "supports_#{feature}?"
      feature = feature.to_sym

      # silence potential redefinition warnings
      silence_warnings do
        # defines the method on the instance
        define_method(method_name) do
          unsupported.delete(feature)
          if block_given?
            begin
              instance_eval(&block)
            rescue => e
              _log.log_backtrace(e)
              unsupported_reason_add(feature, "Internal Error: #{e.message}")
            end
          else
            unsupported_reason_add(feature, reason) unless is_supported
          end
          !unsupported.key?(feature)
        end

        # defines the method on the class
        define_singleton_method(method_name) do
          unsupported.delete(feature)
          # TODO: durandom - make reason evaluate in class context, to e.g. include the name of a subclass (.to_proc?)
          unsupported_reason_add(feature, reason) unless is_supported
          !unsupported.key?(feature)
        end
      end
    end
  end
end
