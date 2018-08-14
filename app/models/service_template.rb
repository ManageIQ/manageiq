class ServiceTemplate < ApplicationRecord
  DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS = 120

  GENERIC_ITEM_SUBTYPES = {
    "custom"          => N_("Custom"),
    "vm"              => N_("Virtual Machine"),
    "playbook"        => N_("Playbook"),
    "hosted_database" => N_("Hosted Database"),
    "load_balancer"   => N_("Load Balancer"),
    "storage"         => N_("Storage")
  }.freeze

  CATALOG_ITEM_TYPES = {
    "amazon"                     => N_("Amazon"),
    "azure"                      => N_("Azure"),
    "generic"                    => N_("Generic"),
    "generic_orchestration"      => N_("Orchestration"),
    "generic_ansible_playbook"   => N_("Ansible Playbook"),
    "generic_ansible_tower"      => N_("Ansible Tower"),
    "generic_container_template" => N_("OpenShift Template"),
    "google"                     => N_("Google"),
    "microsoft"                  => N_("SCVMM"),
    "openstack"                  => N_("OpenStack"),
    "redhat"                     => N_("Red Hat Virtualization"),
    "vmware"                     => N_("VMware")
  }.freeze

  SERVICE_TYPE_ATOMIC    = 'atomic'.freeze
  SERVICE_TYPE_COMPOSITE = 'composite'.freeze

  RESOURCE_ACTION_UPDATE_ATTRS = [:dialog,
                                  :dialog_id,
                                  :fqname,
                                  :configuration_template,
                                  :configuration_template_id,
                                  :configuration_template_type].freeze

  include CustomActionsMixin
  include ServiceMixin
  include OwnershipMixin
  include NewWithTypeStiMixin
  include TenancyMixin
  include ArchivedMixin
  include_concern 'Filter'

  belongs_to :tenant
  # # These relationships are used to specify children spawned from a parent service
  # has_many   :child_services, :class_name => "ServiceTemplate", :foreign_key => :service_template_id
  # belongs_to :parent_service, :class_name => "ServiceTemplate", :foreign_key => :service_template_id

  # # These relationships are used for resources that are processed as part of the service
  # has_many   :vms_and_templates, :through => :service_resources, :source => :resource, :source_type => 'VmOrTemplate'
  has_many   :service_templates, :through => :service_resources, :source => :resource, :source_type => 'ServiceTemplate'
  has_many   :services

  has_one :picture, :dependent => :destroy, :as => :resource, :autosave => true

  belongs_to :service_template_catalog

  has_many   :dialogs, -> { distinct }, :through => :resource_actions
  has_many   :miq_schedules, :as => :resource, :dependent => :destroy

  has_many   :miq_requests, :as => :source, :dependent => :nullify
  has_many   :active_requests, -> { where(:request_state => MiqRequest::ACTIVE_STATES) }, :as => :source, :class_name => "MiqRequest"

  virtual_column   :type_display,                 :type => :string
  virtual_column   :template_valid,               :type => :boolean
  virtual_column   :template_valid_error_message, :type => :string
  virtual_column   :archived,                     :type => :boolean
  virtual_column   :active,                       :type => :boolean

  default_value_for :internal, false
  default_value_for :service_type, SERVICE_TYPE_ATOMIC
  default_value_for(:generic_subtype) { |st| 'custom' if st.prov_type == 'generic' }

  virtual_has_one :config_info, :class_name => "Hash"

  scope :with_service_template_catalog_id,          ->(cat_id) { where(:service_template_catalog_id => cat_id) }
  scope :without_service_template_catalog_id,       ->         { where(:service_template_catalog_id => nil) }
  scope :with_existent_service_template_catalog_id, ->         { where.not(:service_template_catalog_id => nil) }
  scope :displayed,                                 ->         { where(:display => true) }
  scope :public_service_templates,                  ->         { where.not(:internal => true) }

  def self.catalog_item_types
    ci_types = Set.new(Rbac.filtered(ExtManagementSystem.all).flat_map(&:supported_catalog_types))
    ci_types.add('generic_orchestration') if Rbac.filtered(OrchestrationTemplate).exists?
    ci_types.add('generic')
    CATALOG_ITEM_TYPES.each.with_object({}) do |(key, description), hash|
      hash[key] = { :description => description, :display => ci_types.include?(key) }
    end
  end

  def self.create_catalog_item(options, auth_user)
    transaction do
      create_from_options(options).tap do |service_template|
        config_info = options[:config_info].except(:provision, :retirement, :reconfigure)

        workflow_class = MiqProvisionWorkflow.class_for_source(config_info[:src_vm_id])
        if workflow_class
          request = workflow_class.new(config_info, auth_user).make_request(nil, config_info)
          service_template.add_resource(request)
        end
        service_template.create_resource_actions(options[:config_info])
      end
    end
  end

  def self.class_from_request_data(data)
    request_type = data['prov_type']
    if request_type.include?('generic_')
      generic_type = request_type.split('generic_').last
      "ServiceTemplate#{generic_type.camelize}".constantize
    else
      ServiceTemplate
    end
  end

  def update_catalog_item(options, auth_user = nil)
    config_info = validate_update_config_info(options)
    unless config_info
      update_attributes!(options)
      return reload
    end
    transaction do
      update_from_options(options)

      update_service_resources(config_info, auth_user)

      update_resource_actions(config_info)
      save!
    end
    reload
  end

  def children
    service_templates
  end

  def descendants
    children.flat_map { |child| [child] + child.descendants }
  end

  def subtree
    [self] + descendants
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

  def archive
    raise _("Cannot archive while in use") unless active_requests.empty?
    archive!
  end

  def request_class
    ServiceTemplateProvisionRequest
  end

  def request_type
    "clone_to_service"
  end

  def config_info
    options[:config_info] || construct_config_info
  end

  def create_service(service_task, parent_svc = nil)
    nh = attributes.dup
    nh['options'][:dialog] = service_task.options[:dialog]
    (nh.keys - Service.column_names + %w(created_at guid service_template_id updated_at id type prov_type)).each { |key| nh.delete(key) }

    # Hide child services by default
    nh['display'] = false if parent_svc

    # If display is nil, set it to false
    nh['display'] ||= false

    # convert template class name to service class name by naming convention
    nh['type'] = self.class.name.sub('Template', '')

    nh['initiator'] = service_task.options[:initiator] if service_task.options[:initiator]

    svc = Service.create(nh)
    svc.service_template = self

    service_resources.each do |sr|
      nh = sr.attributes.dup
      %w(id created_at updated_at service_template_id).each { |key| nh.delete(key) }
      svc.add_resource(sr.resource, nh) unless sr.resource.nil?
    end

    if parent_svc
      service_resource = ServiceResource.find_by(:id => service_task.options[:service_resource_id])
      parent_svc.add_resource!(svc, service_resource)
    end

    svc.save
    svc
  end

  def composite?
    service_type.to_s.include?(self.class::SERVICE_TYPE_COMPOSITE)
  end

  def atomic?
    service_type.to_s.include?(self.class::SERVICE_TYPE_ATOMIC)
  end

  def type_display
    case service_type
    when self.class::SERVICE_TYPE_ATOMIC    then "Item"
    when self.class::SERVICE_TYPE_COMPOSITE then "Bundle"
    when nil                                then "Unknown"
    else
      service_type.to_s.capitalize
    end
  end

  def create_tasks_for_service(service_task, parent_svc)
    unless parent_svc
      return [] unless self.class.include_service_template?(service_task,
                                                            service_task.source_id,
                                                            parent_svc)
    end
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
      $log.info("Setting Service Owning User to Name=#{user.name}, ID=#{user.id}, Group to Name=#{user.current_group.name}, ID=#{user.current_group.id}")
      service.miq_group = user.current_group
    else
      $log.info("Setting Service Owning User to Name=#{user.name}, ID=#{user.id}")
    end
    service.save
  end

  def self.default_provisioning_entry_point(service_type)
    if service_type == 'atomic'
      '/Service/Provisioning/StateMachines/ServiceProvision_Template/CatalogItemInitialization'
    else
      '/Service/Provisioning/StateMachines/ServiceProvision_Template/CatalogBundleInitialization'
    end
  end

  def self.default_retirement_entry_point
    '/Service/Retirement/StateMachines/ServiceRetirement/Default'
  end

  def self.default_reconfiguration_entry_point
    nil
  end

  def template_valid?
    validate_template[:valid]
  end
  alias template_valid template_valid?

  def template_valid_error_message
    validate_template[:message]
  end

  def validate_template
    missing_resources = service_resources.select { |sr| sr.resource.nil? }

    if missing_resources.present?
      missing_list = missing_resources.collect { |sr| "#{sr.resource_type}:#{sr.resource_id}" }.join(", ")
      return {:valid   => false,
              :message => "Missing Service Resource(s): #{missing_list}"}
    end

    service_resources.detect do |s|
      r = s.resource
      r.respond_to?(:template_valid?) && !r.template_valid?
    end.try(:resource).try(:validate_template) || {:valid => true, :message => nil}
  end

  def validate_order
    service_template_catalog && display
  end
  alias orderable? validate_order

  def provision_action
    resource_actions.find_by(:action => "Provision")
  end

  def update_resource_actions(ae_endpoints)
    resource_action_list.each do |action|
      resource_params = ae_endpoints[action[:param_key]]
      resource_action = resource_actions.find_by(:action => action[:name])
      # If the action exists in updated parameters
      if resource_params
        # And the resource action exists on the template already, update it
        if resource_action
          resource_action.update_attributes!(resource_params.slice(*RESOURCE_ACTION_UPDATE_ATTRS))
        # If the resource action does not exist, create it
        else
          build_resource_action(resource_params, action)
        end
      elsif resource_action
        # If the endpoint does not exist in updated parameters, but exists on the template, delete it
        resource_action.destroy
      end
    end
  end

  def create_resource_actions(ae_endpoints)
    ae_endpoints ||= {}
    resource_action_list.each do |action|
      ae_endpoint = ae_endpoints[action[:param_key]]
      next unless ae_endpoint
      build_resource_action(ae_endpoint, action)
    end
    save!
  end

  def self.create_from_options(options)
    create(options.except(:config_info).merge(:options => { :config_info => options[:config_info] }))
  end
  private_class_method :create_from_options

  def provision_request(user, options = nil, request_options = {})
    request_options[:provision_workflow] = true
    result = order(user, options, request_options)
    raise result[:errors].join(", ") if result[:errors].any?
    result[:request]
  end

  def queue_order(user_id, options, request_options)
    MiqQueue.submit_job(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "order",
      :args        => [user_id, options, request_options],
    )
  end

  def order(user_or_id, options = nil, request_options = {}, schedule_time = nil)
    user     = user_or_id.kind_of?(User) ? user_or_id : User.find(user_or_id)
    workflow = provision_workflow(user, options, request_options)
    if schedule_time
      require 'time'
      time = Time.parse(schedule_time).utc

      errors = workflow.validate_dialog
      return {:errors => errors} unless errors.blank?

      schedule = MiqSchedule.create!(
        :name         => "Order #{self.class.name} #{id} at #{time}",
        :description  => "Order #{self.class.name} #{id} at #{time}",
        :sched_action => {:args => [user.id, options, request_options], :method => "queue_order"},
        :resource     => self,
        :run_at       => {
          :interval   => {:unit => "once"},
          :start_time => time,
          :tz         => "UTC",
        },
      )
      {:schedule => schedule}
    else
      workflow.submit_request
    end
  end

  def provision_workflow(user, dialog_options = nil, request_options = {})
    dialog_options ||= {}
    request_options.delete(:provision_workflow) if request_options[:submit_workflow]

    ra_options = {
      :target             => self,
      :initiator          => request_options[:initiator],
      :submit_workflow    => request_options[:submit_workflow],
      :provision_workflow => request_options[:provision_workflow]
    }

    ResourceActionWorkflow.new(dialog_options, user, provision_action, ra_options).tap do |wf|
      wf.request_options = request_options
    end
  end

  def add_resource(rsc, options = {})
    super
    adjust_service_type
  end

  def self.display_name(number = 1)
    n_('Service Catalog Item', 'Service Catalog Items', number)
  end

  private

  def update_service_resources(config_info, auth_user = nil)
    config_info = config_info.except(:provision, :retirement, :reconfigure)
    workflow_class = MiqProvisionWorkflow.class_for_source(config_info[:src_vm_id])
    if workflow_class
      service_resources.find_by(:resource_type => 'MiqRequest').try(:destroy)
      new_request = workflow_class.new(config_info, auth_user).make_request(nil, config_info)

      add_resource!(new_request)
    end
  end

  def build_resource_action(ae_endpoint, action)
    fqname = ae_endpoint[:fqname] || self.class.send(action[:method], *action[:args]) || ""

    build_options = {:action        => action[:name],
                     :fqname        => fqname,
                     :ae_attributes => {:service_action => action[:name]}}
    build_options.merge!(ae_endpoint.slice(*RESOURCE_ACTION_UPDATE_ATTRS))
    resource_actions.build(build_options)
  end

  def validate_update_config_info(options)
    if options[:service_type] && options[:service_type] != service_type
      raise _('service_type cannot be changed')
    end
    if options[:prov_type] && options[:prov_type] != prov_type
      raise _('prov_type cannot be changed')
    end
    options[:config_info]
  end

  def resource_action_list
    [
      {:name      => ResourceAction::PROVISION,
       :param_key => :provision,
       :method    => 'default_provisioning_entry_point',
       :args      => [service_type]},
      {:name      => ResourceAction::RECONFIGURE,
       :param_key => :reconfigure,
       :method    => 'default_reconfiguration_entry_point',
       :args      => []},
      {:name      => ResourceAction::RETIREMENT,
       :param_key => :retirement,
       :method    => 'default_retirement_entry_point',
       :args      => []}
    ]
  end

  def update_from_options(params)
    options[:config_info] = params[:config_info]
    update_attributes!(params.except(:config_info))
  end

  def construct_config_info
    config_info = {}
    if service_resources.where(:resource_type => 'MiqRequest').exists?
      config_info.merge!(service_resources.find_by(:resource_type => 'MiqRequest').resource.options.compact)
    end

    config_info.merge!(resource_actions_info)
  end

  def resource_actions_info
    config_info = {}
    resource_actions.each do |resource_action|
      resource_options = resource_action.slice(:dialog_id,
                                               :configuration_template_type,
                                               :configuration_template_id).compact
      resource_options[:fqname] = resource_action.fqname
      config_info[resource_action.action.downcase.to_sym] = resource_options.symbolize_keys
    end
    config_info
  end

  def generic_custom_buttons
    CustomButton.buttons_for("Service")
  end

  def adjust_service_type
    svc_type = self.class::SERVICE_TYPE_ATOMIC
    service_resources.try(:each) do |sr|
      if sr.resource_type == 'Service' || sr.resource_type == 'ServiceTemplate'
        svc_type = self.class::SERVICE_TYPE_COMPOSITE
        break
      end
    end

    self.service_type = svc_type
  end
end
