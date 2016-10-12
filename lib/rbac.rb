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

  def self.resources_shared_with(user)
    valid_resources = []

    # TODO: This is very, very likely performance hell.
    Share.by_tenant_inheritance(user.current_tenant).each do |share|
      valid_resources << share.resource if ResourceSharer.valid_share?(share)
    end
    valid_resources
  end

  def self.role_allows?(*args)
    Authorizer.role_allows?(*args)
  end
end
