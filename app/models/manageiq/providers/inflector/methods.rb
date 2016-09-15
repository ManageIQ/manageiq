module ManageIQ::Providers::Inflector::Methods
  extend ActiveSupport::Concern

  included do
    include ClassMethods
  end

  class_methods do
    def provider_name
      ManageIQ::Providers::Inflector.provider_name(self)
    end

    def manager_type
      ManageIQ::Providers::Inflector.manager_type(self)
    end
  end
end
