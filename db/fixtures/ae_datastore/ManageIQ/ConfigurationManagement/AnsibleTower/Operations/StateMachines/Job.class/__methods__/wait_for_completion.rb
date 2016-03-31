#
# Description: Given a Ansible Job Id, check it's status
#
class WaitForCompletion
  JOB_CLASS = 'ManageIQ_Providers_AnsibleTower_ConfigurationManager_Job'.freeze
  def initialize(handle)
    @handle = handle
    @job_id = @handle.get_state_var(:ansible_job_id)
    if @job_id.nil?
      @handle.log(:error, 'Ansible job id not found')
      exit(MIQ_ERROR)
    end
  end

  def main
    @job = @handle.vmdb(JOB_CLASS).find(@job_id)

    if @job.nil?
      @handle.log(:error, 'Ansible job with id : #{@job_id} not found')
      exit(MIQ_ERROR)
    end
    check_status
  end

  def check_status
    status, reason = @job.normalized_live_status
    case status
    when 'transient'
      @handle.root['ae_result'] = 'retry'
      @handle.root['ae_retry_limit'] = 1.minute
    when 'failed', 'create_canceled'
      @handle.root['ae_result'] = 'error'
      @handle.log(:error, "Job failed for #{@job.id} reason #{reason}")
      @job.refresh_ems
    when 'create_complete'
      @handle.root['ae_result'] = 'ok'
      @job.refresh_ems
    else
      @handle.root['ae_result'] = 'error'
      @handle.log(:error, "Job failed for #{@job.id} Unknown status #{status} reason #{reason}")
      @job.refresh_ems
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  WaitForCompletion.new($evm).main
end
