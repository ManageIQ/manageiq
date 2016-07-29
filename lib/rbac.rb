require 'rbac/filterer'
require 'rbac/authorizer'

module Rbac
  def self.search(*args)
    Filterer.search(*args)
  end

  def self.filtered_object(*args)
    Filterer.filtered_object(*args)
  end

  def self.filtered(*args)
    Filterer.filtered(*args)
  end

  def self.accessible_tenant_ids_strategy(*args)
    Filterer.accessible_tenant_ids_strategy(*args)
  end
end
