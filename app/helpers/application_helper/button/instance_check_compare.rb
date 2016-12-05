class ApplicationHelper::Button::InstanceCheckCompare < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    !@record.kind_of?(OrchestrationStack) || @display != 'instances'
  end

  def disabled?
    @error_message = _('No Compliance Policies assigned to this virtual machine') unless
        @record.has_compliance_policies?
    @error_message.present?
  end
end
