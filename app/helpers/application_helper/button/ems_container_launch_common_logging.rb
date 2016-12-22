class ApplicationHelper::Button::EmsContainerLaunchCommonLogging < ApplicationHelper::Button::GenericFeatureButton
  def initialize(view_context, view_binding, instance_data, props)
    props ||= {}
    props.store_path(:options, :feature, :common_logging)
    super(view_context, view_binding, instance_data, props)
  end

  def disabled?
    ems = @record.ext_management_system
    !visible? || ContainerRoute.find_by(:name   => ems.common_logging_route_name,
                                        :ems_id => ems.id).blank?
  end
end
