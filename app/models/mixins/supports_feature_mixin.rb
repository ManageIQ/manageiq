module SupportsFeatureMixin
  #
  # Including this in a model gives you a DSL to make features supported or not
  #
  #   class Post
  #     include SupportsFeatureMixin
  #     supports :publish
  #     supports_not :fake, "We keep it real"
  #     supports :archive do |post|
  #       post.unsupported[:archive] = "Its too good" if post.featured?
  #     end
  #   end
  #
  # To make a feature conditionally supported, pass a block to the +supports+ method.
  # The block receives the instance as an argument.
  # If you set a key with the name of the feature to +instance.unsupported+ with a reason
  # then the feature will be unsupported and the reason will be accessible through
  #
  #   instance.unsupported[:feature]
  #
  # The above allows you to call +support_feature?+ methods on the Class and Instance:
  #
  #   Post.supports_publish?                       # => true
  #   Post.new.supports_publish?                   # => true
  #   Post.supports_fake?                          # => false
  #   Post.supports_archive?                       # => true
  #   Post.new(featured: true).supports_archive?   # => false
  #
  # To get a reason why a feature is unsupported use the +unsupported+ method
  #
  #   Post.unsupported[:publish]                   # => nil
  #   Post.unsupported[:fake]                      # => "We keep it real"
  #   Post.new(featured).unsupported[:archive]     # => "Its too good"
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

  def unsupported
    @unsupported ||= Hash.new do |_hash, feature|
      unsupported[feature] unless public_send("supports_#{feature}?")
    end
  end

  class_methods do
    def unsupported
      # TODO: durandom - is Thread.current needed here?
      Thread.current["unsupported_#{object_id}"] ||= Hash.new do |_hash, feature|
        unsupported[feature] unless public_send("supports_#{feature}?")
      end
    end

    def supports(feature, &block)
      send(:define_supports_methods, feature, true, &block)
    end

    def supports_not(feature, reason)
      send(:define_supports_methods, feature, false, reason)
    end

    private

    def define_supports_methods(feature, is_supported, reason = nil)
      method_name = "supports_#{feature}?"

      define_method(method_name) do
        unsupported.delete(feature)
        if block_given?
          yield(self)
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
