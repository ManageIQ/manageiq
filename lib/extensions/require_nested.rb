module RequireNested
  # See also: include_concern
  def require_nested(name)
    return if const_defined?(name, false)

    filename = "#{self}::#{name}".underscore
    filename = name.to_s.underscore if self == Object
    if Rails.application.config.cache_classes
      raise LoadError, "No such file to load -- #{filename}" unless ActiveSupport::Dependencies.search_for_file(filename)
      autoload name, filename
    else
      require_dependency filename
    end

    # If the nested constant has a top-level constant with the same name, then both
    # must be defined at the same time, otherwise the Rails autoloader can get
    # confused.
    #
    # For example, suppose we have the following
    #
    #     # app/models/thing_grouper.rb
    #     class ThingGrouper < ApplicationRecord
    #       require_nested :Thing
    #     end
    #
    #     # app/models/thing_grouper/thing.rb
    #     class ThingGrouper::Thing; end
    #
    #     # app/models/thing.rb
    #     class Thing < ApplicationRecord; end
    #
    # When the require_nested call is made, we will define `ThingGrouper`'s nested
    # `Thing`, but at the same time we must also define `::Thing` in order to allow
    # the Rails autloader to work correctly.  We do this by using a special-case call
    # to `require_nested` on `Object`, if a top-level `thing.rb` file exists.
    if ActiveSupport::Dependencies.search_for_file(name.to_s.underscore) && self != Object
      Object.require_nested name
    end
  end
end

Module.include RequireNested
