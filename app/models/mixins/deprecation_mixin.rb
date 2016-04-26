module DeprecationMixin
  extend ActiveSupport::Concern

  module ClassMethods
    private

    def deprecate_belongs_to(old_belongs_to, new_belongs_to)
      deprecate_attribute_methods(old_belongs_to, new_belongs_to)
      ["_id", "_id=", "_id?"].each do |suffix|
        define_method("#{old_belongs_to}#{suffix}") do |*args|
          args.present? ? send("#{new_belongs_to}#{suffix}", *args) : send("#{new_belongs_to}#{suffix}")
        end
        Vmdb::Deprecation.deprecate_methods(self, "#{old_belongs_to}#{suffix}" => "#{new_belongs_to}#{suffix}")
      end
      virtual_belongs_to(old_belongs_to)
    end

    def deprecate_attribute(old_attribute, new_attribute)
      deprecate_attribute_methods(old_attribute, new_attribute)
      virtual_attribute(old_attribute, -> { type_for_attribute(new_attribute.to_s) })
    end

    def deprecate_attribute_methods(old_attribute, new_attribute)
      alias_attribute old_attribute, new_attribute
      ["", "=", "?"].each { |suffix| Vmdb::Deprecation.deprecate_methods(self, "#{old_attribute}#{suffix}" => "#{new_attribute}#{suffix}") }
    end
  end
end
