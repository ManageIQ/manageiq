class ApplicationHelper::Button::VmPolicy < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    @record.host.try(:vmm_product).to_s.casecmp("workstation").nonzero?
  end
end
