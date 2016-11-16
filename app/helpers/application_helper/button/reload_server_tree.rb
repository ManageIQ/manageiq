class ApplicationHelper::Button::ReloadServerTree < ApplicationHelper::Button::Basic
  needs :@sb

  def visible?
    diagnostics_tree && roles_servers_or_servers_roles_tab
  end

  private

  def diagnostics_tree
    @view_context.x_active_tree == :diagnostics_tree &&
  end

  def roles_servers_or_servers_roles_tab
    %w(diagnostics_roles_servers diagnostics_servers_roles).include?(@sb[:active_tab])
  end
end
