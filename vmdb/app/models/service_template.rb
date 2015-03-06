class ServiceTemplate < ActiveRecord::Base
  DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS = 120
  include ServiceMixin
  include OwnershipMixin
  include NewWithTypeStiMixin

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

  virtual_has_many :custom_buttons
  virtual_column   :type_display, :type => :string

  default_value_for :service_type,  'unknown'

  validate :dialog_when_catalog

  def custom_buttons
    CustomButton.buttons_for(self).select { |b| b.parent.nil? }
  end

  def vms_and_templates
    []
  end

  def destroy
    parent_svcs = self.parent_services
    raise MiqException::MiqServiceError, "Cannot delete a service that is the child of another service." unless parent_svcs.blank?

    self.service_resources.each do |sr|
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
    nh = self.attributes.dup
    nh['options'][:dialog] = service_task.options[:dialog]
    (nh.keys - Service.column_names + %w{created_at guid service_template_id updated_at id type prov_type}).each {|key| nh.delete(key)}

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
    self.service_resources.each do |sr|
      nh = sr.attributes.dup
      %W{id created_at updated_at service_template_id}.each {|key| nh.delete(key)}
      svc.add_resource(sr.resource, nh)
    end

    parent_svc.add_resource!(svc) unless parent_svc.nil?

    svc.save
    return svc
  end

  def set_service_type
    svc_type = nil

    if self.service_resources.size.zero?
      svc_type = 'unknown'
    else
      self.service_resources.each do |sr|
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
    self.service_type.to_s.include?('composite')
  end

  def atomic?
    self.service_type.to_s.include?('atomic')
  end

  def type_display
    case self.service_type
    when "atomic"    then "Item"
    when "composite" then "Bundle"
    when nil         then "Unknown"
    else
      self.service_type.to_s.capitalize
    end
  end

  def create_tasks_for_service(service_task, parent_svc)
    svc = create_service(service_task, parent_svc)

    user = User.find_by_userid(service_task.userid)
    set_ownership(svc, user) unless user.nil?

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
        %w{created_on updated_on type state status message}.each {|key| nh.delete(key)}
        nh['options'] = parent_service_task.options.dup
        nh['options'].delete(:child_tasks)
        # Initial Options[:dialog] to an empty hash so we do not pass down dialog values to child services tasks
        nh['options'][:dialog] = {}
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

  private

  # validate presence of a dialog when attached to a catalog
  def dialog_when_catalog
    if display && resource_actions.collect { |a| a.dialog.nil? }.reduce(:&)
      errors.add(:dialog, "has to be set if Display in Catalog is chosen")
    end
  end
end
