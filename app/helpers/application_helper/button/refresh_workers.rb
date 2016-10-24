class ApplicationHelper::Button::RefreshWorkers < ApplicationHelper::Button::Basic
  needs :@record, :@lastaction, :@sb, :@layout

  def visible?
    return false if miq? && !(ops? && diagnostics_worker_tab?)
    return !%w(download_logs evm_logs audit_logs).include?(@lastaction) if @record.class == NilClass
    true
  end

  private

  def diagnostics_worker_tab?
    @view_context.x_active_tree == :diagnostics_tree && @sb[:active_tab] == 'diagnostics_workers'
  end

  def miq?
    @record.class == MiqServer || @record.class == MiqRegion
  end

  def ops?
    @layout == 'ops'
  end
end
