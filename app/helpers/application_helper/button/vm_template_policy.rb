class ApplicationHelper::Button::VmTemplatePolicy < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.host.try(:vmm_product).to_s.casecmp("workstation").nonzero?
  end
end
