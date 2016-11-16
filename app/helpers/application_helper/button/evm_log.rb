class ApplicationHelper::Button::EvmLog < ApplicationHelper::Button::Basic
  def visible?
    @view_context.x_active_tree == :diagnostics_tree && @sb[:active_tab] == "diagnostics_evm_log"
  end
end
