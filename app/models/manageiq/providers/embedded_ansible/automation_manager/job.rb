class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include CiFeatureMixin

  require_nested :Status

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::AutomationManager", :inverse_of => false
  belongs_to :playbook, :foreign_key => :configuration_script_base_id, :inverse_of => false

  belongs_to :miq_task, :foreign_key => :ems_ref, :inverse_of => false

  virtual_has_many :job_plays

  #
  # Allowed options are
  #   :limit      => String
  #   :extra_vars => Hash
  #
  def self.create_stack(playbook, options = {})
    new(:name                  => playbook.name,
        :ext_management_system => playbook.manager,
        :verbosity             => options[:verbosity].to_i,
        :authentications       => collect_authentications(playbook.manager, options),
        :playbook              => playbook).tap do |stack|
      stack.send(:update_with_provider_object, raw_create_stack(playbook, options))
    end
  end

  def self.raw_create_stack(playbook, options = {})
    playbook.run(options)
  rescue StandardError => e
    _log.error("Failed to create job from playbook(#{playbook.name}), error: #{e}")
    raise MiqException::MiqOrchestrationProvisionError, e.to_s, e.backtrace
  end

  class << self
    alias create_job create_stack
    alias raw_create_job raw_create_stack
  end

  def raw_status
    Status.new(miq_task, nil)
  end

  def raw_stdout(format = 'txt')
    case format
    when "json" then raw_stdout_json
    when "html" then raw_stdout_html
    else             raw_stdout_txt
    end
  end

  def refresh_ems
    update_with_provider_object(self)
  end

  def job_plays
    resources.where(:resource_category => 'job_play').order(:start_time)
  end

  def playbook_set_stats
    raw_stdout_json.dig(-1, 'event_data', 'artifact_data')
  end

  # Intend to be called by UI to display stdout. The stdout is stored in MiqTask#task_results or #message if error
  # Since the task_results may contain a large block of data, it is desired to remove the task upon receiving the data
  def raw_stdout_via_worker(userid, format = 'txt')
    unless MiqRegion.my_region.role_active?("embedded_ansible")
      msg = "Cannot get standard output of this playbook because the embedded Ansible role is not enabled"
      return MiqTask.create(
        :name    => 'ansible_stdout',
        :userid  => userid || 'system',
        :state   => MiqTask::STATE_FINISHED,
        :status  => MiqTask::STATUS_ERROR,
        :message => msg
      ).id
    end

    options = {:userid => userid || 'system', :action => 'ansible_stdout'}
    queue_options = {
      :class_name  => self.class,
      :method_name => 'raw_stdout',
      :instance_id => id,
      :args        => [format],
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => nil
    }

    MiqTask.generic_action_with_callback(options, queue_options)
  end

  def retireable?
    false
  end

  private

  def self.collect_authentications(manager, options)
    credential_ids = options.values_at(
      :credential,
      :cloud_credential,
      :network_credential,
      :vault_credential
    ).compact
    manager.credentials.where(:id => credential_ids)
  end
  private_class_method :collect_authentications

  def update_with_provider_object(raw_job)
    transaction do
      self.miq_task ||= raw_job.miq_task

      self.status      = miq_task.state
      self.start_time  = miq_task.started_on
      self.finish_time = raw_status.completed? ? miq_task.updated_on : nil

      update_plays
      save!
    end
  end

  def update_plays
    plays = raw_stdout_json.select do |playbook_event|
      playbook_event["event"] == "playbook_on_play_start"
    end.collect do |play|
      {
        :name              => play["event_data"]["play"],
        :resource_status   => play["failed"] ? 'failed' : 'successful',
        :start_time        => play["created"],
        :ems_ref           => play["uuid"],
        :resource_category => "job_play"
      }
    end

    # Set each play's finish_time to the next play's start time, with the
    # final play's finish time set to the entire job's finish time.
    plays.each_cons(2) do |last_play, play|
      last_play[:finish_time] = play[:start_time]
    end
    plays[-1][:finish_time] = finish_time if plays.any?

    old_resources = resources.index_by(&:ems_ref)
    self.resources = plays.collect do |play_hash|
      if (old_resource = old_resources[play_hash[:ems_ref].to_s])
        old_resource.update!(play_hash)
        old_resource
      else
        OrchestrationStackResource.new(play_hash)
      end
    end
  end

  def raw_stdout_json
    miq_task.try(&:context_data).try(:[], :ansible_runner_stdout) || []
  end

  def raw_stdout_txt
    raw_stdout_json.collect { |j| j["stdout"] }.join("\n")
  end

  def raw_stdout_html
    text = raw_stdout_txt
    text = _("No output available") if text.blank?
    TerminalToHtml.render(text)
  end
end
