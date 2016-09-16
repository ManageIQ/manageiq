class ApplicationHelper::Button::CatalogItemButton < ApplicationHelper::Button::Basic

  def role_allows_feature?
    # when user has the privilege to edit Catalog Item, he can also add/edit buttons/button groups
    @view_context.current_user.role_allows_any?(:identifiers => %w(catalogitem_new catalogitem_edit atomic_catalogitem_new atomic_catalogitem_edit))
  end
end

