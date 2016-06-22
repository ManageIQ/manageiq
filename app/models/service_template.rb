class ServiceTemplate < ApplicationRecord
  DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS = 120
  include ServiceMixin
  include OwnershipMixin
  include NewWithTypeStiMixin
  include TenancyMixin
  include_concern 'Filter'

  belongs_to :tenant
  # # These relationships are used to specify children spawned from a parent service
  # has_many   :child_services, :class_name => "ServiceTemplate", :foreign_key => :service_template_id
  # belongs_to :parent_service, :class_name => "ServiceTemplate", :foreign_key => :service_template_id

  # # These relationships are used for resources that are processed as part of the service
  # has_many   :vms_and_templates, :through => :service_resources, :source => :resource, :source_type => 'VmOrTemplate'
  has_many   :service_templates, :through => :service_resources, :source => :resource, :source_type => 'ServiceTemplate'
  has_many   :services

  has_one   :picture,         :dependent => :destroy, :as => :resource, :autosave => true

  has_many   :custom_button_sets, :as => :owner, :dependent => :destroy
  belongs_to :service_template_catalog

  has_many   :dialogs, -> { distinct }, :through => :resource_actions

  virtual_has_many :custom_buttons
  virtual_column   :type_display,                 :type => :string
  virtual_column   :template_valid,               :type => :boolean
  virtual_column   :template_valid_error_message, :type => :string

  default_value_for :service_type,  'unknown'

  virtual_has_one :custom_actions, :class_name => "Hash"
  virtual_has_one :custom_action_buttons, :class_name => "Array"

  def children
    service_templates
  end

  def descendants
    children.flat_map { |child| [child] + child.descendants }
  end

  def subtree
    [self] + descendants
  end

  def custom_actions
    generic_button_group = CustomButton.buttons_for("Service").select { |button| !button.parent.nil? }
    custom_button_sets_with_generics = custom_button_sets + generic_button_group.map(&:parent).uniq.flatten
    {
      :buttons       => custom_buttons.collect(&:expanded_serializable_hash),
      :button_groups => custom_button_sets_with_generics.collect do |button_set|
        button_set.serializable_hash.merge(:buttons => button_set.children.collect(&:expanded_serializable_hash))
      end
    }
  end

  def custom_action_buttons
    custom_buttons + custom_button_sets.collect(&:children).flatten
  end

  def custom_buttons
    service_buttons = CustomButton.buttons_for("Service").select { |button| button.parent.nil? }
    service_buttons + CustomButton.buttons_for(self).select { |b| b.parent.nil? }
  end

  def vms_and_templates
    []
  end

  def destroy
    parent_svcs = parent_services
    unless parent_svcs.blank?
      raise MiqException::MiqServiceError, _("Cannot delete a service that is the child of another service.")
    end

    service_resources.each do |sr|
      rsc = sr.resource
      rsc.destroy if rsc.kind_of?(MiqProvisionRequestTemplate)
    end
    super
  end

  def request_class
    ServiceTemplateProvisionRequest
  end

  def request_type
    "clone_to_service"
  end

  def create_service(service_task, parent_svc = nil)
    nh = attributes.dup
    nh['options'][:dialog] = service_task.options[:dialog]
    (nh.keys - Service.column_names + %w(created_at guid service_template_id updated_at id type prov_type)).each { |key| nh.delete(key) }

    # Hide child services by default
    nh[:display] = false if parent_svc

    # convert template class name to service class name by naming convention
    nh[:type] = self.class.name.sub('Template', '')

    # Determine service name
    # target_name = self.get_option(:target_name)
    # nh.merge!('name' => target_name) unless target_name.blank?
    svc = Service.create(nh)
    svc.service_template = self

    # self.options[:service_guid] = svc.guid
    service_resources.each do |sr|
      nh = sr.attributes.dup
      %w(id created_at updated_at service_template_id).each { |key| nh.delete(key) }
      svc.add_resource(sr.resource, nh) unless sr.resource.nil?
    end

    parent_svc.add_resource!(svc) unless parent_svc.nil?

    svc.save
    svc
  end

  def set_service_type
    svc_type = nil

    if service_resources.size.zero?
      svc_type = 'unknown'
    else
      service_resources.each do |sr|
        if sr.resource_type == 'Service' || sr.resource_type == 'ServiceTemplate'
          svc_type = 'composite'
          break
        end
      end
      svc_type = 'atomic' if svc_type.blank?
    end

    self.service_type = svc_type
  end

  def composite?
    service_type.to_s.include?('composite')
  end

  def atomic?
    service_type.to_s.include?('atomic')
  end

  def type_display
    case service_type
    when "atomic"    then "Item"
    when "composite" then "Bundle"
    when nil         then "Unknown"
    else
      service_type.to_s.capitalize
    end
  end

  def create_tasks_for_service(service_task, parent_svc)
    return [] unless self.class.include_service_template?(service_task,
                                                          service_task.source_id,
                                                          parent_svc) unless parent_svc
    svc = create_service(service_task, parent_svc)

    set_ownership(svc, service_task.get_user)

    service_task.destination = svc

    create_subtasks(service_task, svc)
  end

  # default implementation to create subtasks from service resources
  def create_subtasks(parent_service_task, parent_service)
    tasks = []
    service_resources.each do |child_svc_rsc|
      scaling_min = child_svc_rsc.scaling_min
      1.upto(scaling_min).each do |scaling_idx|
        nh = parent_service_task.attributes.dup
        %w(id created_on updated_on type state status message).each { |key| nh.delete(key) }
        nh['options'] = parent_service_task.options.dup
        nh['options'].delete(:child_tasks)
        # Initial Options[:dialog] to an empty hash so we do not pass down dialog values to child services tasks
        nh['options'][:dialog] = {}
        next if child_svc_rsc.resource_type == "ServiceTemplate" &&
                !self.class.include_service_template?(parent_service_task,
                                                      child_svc_rsc.resource.id,
                                                      parent_service)
        new_task = parent_service_task.class.new(nh)
        new_task.options.merge!(
          :src_id              => child_svc_rsc.resource.id,
          :scaling_idx         => scaling_idx,
          :scaling_min         => scaling_min,
          :service_resource_id => child_svc_rsc.id,
          :parent_service_id   => parent_service.id,
          :parent_task_id      => parent_service_task.id,
        )
        new_task.state  = 'pending'
        new_task.status = 'Ok'
        new_task.source = child_svc_rsc.resource
        new_task.save!
        new_task.after_request_task_create
        parent_service_task.miq_request.miq_request_tasks << new_task

        tasks << new_task
      end
    end
    tasks
  end

  def set_ownership(service, user)
    return if user.nil?
    service.evm_owner = user
    if user.current_group
      $log.info "Setting Service Owning User to Name=#{user.name}, ID=#{user.id}, Group to Name=#{user.current_group.name}, ID=#{user.current_group.id}"
      service.miq_group = user.current_group
    else
      $log.info "Setting Service Owning User to Name=#{user.name}, ID=#{user.id}"
    end
    service.save
  end

  def self.default_provisioning_entry_point
    '/Service/Provisioning/StateMachines/ServiceProvision_Template/default'
  end

  def self.default_retirement_entry_point
    '/Service/Retirement/StateMachines/ServiceRetirement/default'
  end

  def template_valid?
    validate_template[:valid]
  end
  alias_method :template_valid, :template_valid?

  def template_valid_error_message
    validate_template[:message]
  end

  def validate_template
    service_resources.detect do |s|
      r = s.resource
      r.respond_to?(:template_valid?) && !r.template_valid?
    end.try(:resource).try(:validate_template) || {:valid => true, :message => nil}
  end

  def validate_order
    service_template_catalog && display
  end
  alias orderable? validate_order
end
