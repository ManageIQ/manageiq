class ApplicationHelper::Button::VmRefresh < ApplicationHelper::Button::Basic
  def skip?
    !@record.ext_management_system &&
    !(@record.host &&
      @record.host.vmm_product.casecmp("workstation").zero?)
  end
end
