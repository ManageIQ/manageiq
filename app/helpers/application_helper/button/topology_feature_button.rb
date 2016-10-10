class ApplicationHelper::Button::TopologyFeatureButton < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    return false if @record.kind_of?(ManageIQ::Providers::InfraManager)
    super
  end
end
