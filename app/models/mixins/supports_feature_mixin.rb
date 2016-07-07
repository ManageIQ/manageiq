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
  # The above allows you to call +supports_feature?+ methods on the Class and Instance:
  #
  #   Post.supports_publish?                       # => true
  #   Post.new.supports_publish?                   # => true
  #   Post.supports_fake?                          # => false
  #   Post.supports_archive?                       # => true
  #   Post.new(featured: true).supports_archive?   # => false
  #
  # To get a reason why a feature is unsupported use the +unsupported+ method
  # Note: Because providing a reason for an unsupported feature is optional, you should
  #       not rely on checking the reason to be nil for a feature to be unsupported.
  #       You have to use +supports_feature?+
  #
  #   Post.unsupported_reason(:publish)                     # => nil
  #   Post.unsupported_reason(:fake)                        # => "We keep it real"
  #   Post.new(featured: true).unsupported_reason(:archive) # => "Its too good"
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

  def unsupported_reason(feature)
    public_send("supports_#{feature}?") unless unsupported.key?(feature)
    unsupported[feature]
  end

  private

  def unsupported_reason_add(feature, reason)
    unsupported[feature] = reason
  end

  def unsupported
    @unsupported ||= {}
  end

  class_methods do
    def unsupported_reason(feature)
      public_send("supports_#{feature}?") unless unsupported.key?(feature)
      unsupported[feature]
    end

    def supports(feature, &block)
      send(:define_supports_methods, feature, true, &block)
    end

    def supports_not(feature, reason: nil)
      send(:define_supports_methods, feature, false, reason)
    end

    private

    def unsupported
      # This is a class variable and it might be modified during runtime
      # because we dont eager load all classes at boot time, so it needs to be thread safe
      @unsupported ||= Concurrent::Hash.new
    end

    def unsupported_reason_add(feature, reason)
      unsupported[feature] = reason
    end

    def define_supports_methods(feature, is_supported, reason = nil, &block)
      method_name = "supports_#{feature}?"

      define_method(method_name) do
        unsupported.delete(feature)
        if block_given?
          instance_eval(&block)
        else
          unsupported[feature] = reason unless is_supported
        end
        !unsupported.key?(feature)
      end

      define_singleton_method(method_name) do
        unsupported.delete(feature)
        # TODO: durandom - make reason evaluate in class context, to e.g. include the name of a subclass (.to_proc?)
        unsupported[feature] = reason unless is_supported
        !unsupported.key?(feature)
      end
    end
  end
end
