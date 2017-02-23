require 'ansible_tower_client'
module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job
  extend ActiveSupport::Concern

  module ClassMethods
    #
    # Allowed options are
    #   :limit      => String
    #   :extra_vars => Hash
    #
    def create_stack(template, options = {})
      self.new(:name                  => template.name,
          :ext_management_system => template.manager,
          :job_template          => template).tap do |stack|
        stack.send(:update_with_provider_object, raw_create_stack(template, options))
      end
    end

    def raw_create_stack(template, options = {})
      template.run(options)
    rescue => err
      _log.error "Failed to create job from template(#{name}), error: #{err}"
      raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
    end

    def db_name
      'ConfigurationJob'
    end

    def status_class
      "#{self.name}::Status".constantize
    end
  end

  included do
    belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager"
    belongs_to :job_template, :foreign_key => :orchestration_template_id, :class_name => "ConfigurationScript"

    class << self
      alias create_job create_stack
      alias raw_create_job raw_create_stack
    end
  end

  def refresh_ems
    ext_management_system.with_provider_connection do |connection|
      update_with_provider_object(connection.api.jobs.find(ems_ref))
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "Refreshing job(#{name}, ems_ref=#{ems_ref}), error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def update_with_provider_object(raw_job)
    self.ems_ref = raw_job.id
    self.status = raw_job.status
    self.parameters =
      raw_job.extra_vars_hash.collect do |para_key, para_val|
        OrchestrationStackParameter.new(:name => para_key, :value => para_val, :ems_ref => "#{raw_job.id}_#{para_key}")
      end if parameters.empty?
    save!
  end
  private :update_with_provider_object

  def raw_status
    ext_management_system.with_provider_connection do |connection|
      raw_job = connection.api.jobs.find(ems_ref)
      self.class.status_class.new(raw_job.status, nil)
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "AnsibleTower Job #{name} with id(#{id}) status error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  def raw_stdout
    ext_management_system.with_provider_connection do |connection|
      connection.api.jobs.find(ems_ref).stdout
    end
  rescue AnsibleTowerClient::ResourceNotFoundError
    msg = "AnsibleTower Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "Reading AnsibleTower Job #{name} with id(#{id}) stdout failed with error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

end
