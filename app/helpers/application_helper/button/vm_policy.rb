class ApplicationHelper::Button::VmPolicy < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    @record.host.try(:vmm_product).to_s.casecmp("workstation")
  end
end
