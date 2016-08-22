class ApplicationHelper::Button::VmPolicy < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    @record.host.vmm_product.to_s.casecmp("workstation") if @record.host
  end
end
