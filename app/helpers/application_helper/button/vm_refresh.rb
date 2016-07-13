class ApplicationHelper::Button::VmRefresh < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.ext_management_system &&
    !(@record.host &&
      @record.host.vmm_product.casecmp("workstation").zero?)
  end
end
