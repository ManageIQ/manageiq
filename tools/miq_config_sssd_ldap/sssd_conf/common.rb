require 'miqldap_configuration'

module MiqConfigSssdLdap
  class Common
    USER_ATTRS = %w[mail givenname sn displayname domainname].freeze

    attr_reader :initial_settings, :installation_specific_fields

    def initialize(installation_specific_fields, initial_settings)
      @installation_specific_fields = installation_specific_fields
      @initial_settings = initial_settings
    end

    def section_name
      self.class.name.downcase.split('::').last
    end

    def new_attribute_values
      installation_specific_fields.each_with_object({}) do |attribute, hsh|
        hsh[attribute.to_sym] = public_send(attribute)
      end
    end

    def update_attribute_values(current_attribute_values)
      current_attribute_values[section_name.to_sym] ||= {}
      current_attribute_values[section_name.to_sym].merge(new_attribute_values)
    end
  end
end
