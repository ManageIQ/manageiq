module TenancyMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def scope_by_tenant?
      true
    end

    def accessible_tenant_ids(user_or_group)
      tenant = user_or_group.try(:current_tenant)
      return [] unless tenant

      tenant.accessible_tenant_ids(self)
    end

    # Any class including this mixin gets the default strategy :ancestor_ids
    # It can use a different stategy by implementing this method.
    #
    # It should accept any of the relationship_mixin methods including:
    #   :parent_ids
    #   :ancestor_ids
    #   :child_ids
    #   :sibling_ids
    #   :descendant_ids
    #   ...
    def accessible_tenant_ids_strategy
      :ancestor_ids
    end
  end
end
