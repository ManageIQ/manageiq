class ApplicationHelper::Button::VmRefresh < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    @record.ext_management_system ||
    @record.host.try(:vmm_product).to_s.casecmp("workstation").zero?
  end
end
