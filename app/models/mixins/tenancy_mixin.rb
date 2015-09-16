module TenancyMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def scope_by_tenant?
      true
    end
  end
end
