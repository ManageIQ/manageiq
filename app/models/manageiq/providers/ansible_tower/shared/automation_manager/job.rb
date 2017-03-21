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
    belongs_to :playbook, :foreign_key => :configuration_script_base_id

    virtual_has_many :job_plays

    class << self
      alias create_job create_stack
      alias raw_create_job raw_create_stack
    end
  end

  def job_plays
    resources.where(:resource_category => 'job_play').order(:start_time)
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
    update_attributes(
      :ems_ref     => raw_job.id,
      :status      => raw_job.status,
      :start_time  => raw_job.started,
      :finish_time => raw_job.finished,
      :verbosity   => raw_job.verbosity
    )

    update_parameters(raw_job) if parameters.empty?

    update_credentials(raw_job) if authentications.empty?

    update_plays(raw_job)
  end
  private :update_with_provider_object

  def update_parameters(raw_job)
    self.parameters = raw_job.extra_vars_hash.collect do |para_key, para_val|
      OrchestrationStackParameter.new(:name => para_key, :value => para_val, :ems_ref => "#{raw_job.id}_#{para_key}")
    end
  end
  private :update_parameters

  def update_credentials(raw_job)
    credential_types = %w(credential_id cloud_credential_id network_credential_id)
    credential_refs = credential_types.collect { |attr| raw_job.try(attr) }.delete_blanks
    self.authentications = ext_management_system.credentials.where(:manager_ref => credential_refs)
  end
  private :update_credentials

  def update_plays(raw_job)
    last_play_hash = nil
    plays = raw_job.job_plays.collect do |play|
      {
        :name              => play.play,
        :resource_status   => play.failed ? 'failed' : 'successful',
        :start_time        => play.started,
        :ems_ref           => play.id,
        :resource_category => 'job_play'
      }.tap do |h|
        last_play_hash[:finish_time] = play.started if last_play_hash
        last_play_hash = h
      end
    end
    last_play_hash[:finish_time] = raw_job.finished if last_play_hash

    old_resources = resources
    self.resources = plays.collect do |play_hash|
      old_resource = old_resources.find { |o| o.ems_ref == play_hash[:ems_ref].to_s }
      if old_resource
        old_resource.update_attributes(play_hash)
        old_resource
      else
        OrchestrationStackResource.new(play_hash)
      end
    end
  end
  private :update_plays

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
