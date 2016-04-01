require 'ansible_tower_client'
class ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job < ::OrchestrationStack
  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::ConfigurationManager"
  belongs_to :job_template, :foreign_key => :orchestration_template_id, :class_name => "ConfigurationScript"

  #
  # Allowed options are
  #   :limit      => String
  #   :extra_vars => Hash
  #
  def self.create_stack(template, options = {})
    stack = new(:name                  => template.name,
                :ext_management_system => template.manager,
                :job_template          => template)
    stack.send(:update_with_provider_object, raw_create_stack(template, options))
    stack
  end

  def self.raw_create_stack(template, options = {})
    template.run(options)
  rescue => err
    _log.error "Failed to create job from template(#{name}), error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  class << self
    alias create_job create_stack
    alias raw_create_job raw_create_stack
  end

  def refresh_ems
    ext_management_system.with_provider_connection do |connection|
      update_with_provider_object(connection.api.jobs.find(ems_ref))
    end
  rescue => err
    _log.error "Refreshing job(#{name}, ems_ref=#{ems_ref}), error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def update_with_provider_object(raw_job)
    self.ems_ref = raw_job.id
    self.status = raw_job.status
    save!
  end
  private :update_with_provider_object

  def raw_status
    ext_management_system.with_provider_connection do |connection|
      raw_job = connection.api.jobs.find(ems_ref)
      Status.new(raw_job.status, nil)
    end
  rescue AnsibleTowerClient::ResourceNotFound
    msg = "AnsibleTower Job #{name} with id(#{id}) does not exist on #{ext_management_system.name}"
    raise MiqException::MiqOrchestrationStackNotExistError, msg
  rescue => err
    _log.error "AnsibleTower Job #{name} with id(#{id}) status error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end
