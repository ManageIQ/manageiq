#
# Description: Launch a Ansible Job Template and save the job id
#              in the state variables so we can use it when we
#              wait for the job to finish.
#

class LaunchAnsibleJob
  ANSIBLE_VAR_REGEX = Regexp.new(/(.*)=(.*$)/)
  SCRIPT_CLASS = 'ConfigurationScript'.freeze
  JOB_CLASS = 'ManageIQ_Providers_AnsibleTower_ConfigurationManager_Job'.freeze

  def initialize(handle)
    @handle = handle
  end

  def main
    run(job_template, target)
  end

  private

  def target
    vm = @handle.root['vm'] || vm_from_request
    vm.name if vm
  end

  def vm_from_request
    @handle.root["miq_provision"].try(:destination)
  end

  def ansible_vars(object, ext_vars)
    return ext_vars unless object
    ansible_vars(object.parent, object_vars(object, ext_vars))
  end

  def object_vars(object, ext_vars)
    key_list = object.attributes.keys.select { |k| k.start_with?('param', 'dialog_param') }
    key_list.each_with_object(ext_vars) do |key, hash|
      match_data = ANSIBLE_VAR_REGEX.match(object[key])
      hash[match_data[1].strip] ||= match_data[2] if match_data
    end
  end

  def var_search(obj, name)
    return nil unless obj
    obj.attributes.key?(name) ? obj.attributes[name] : var_search(obj.parent, name)
  end

  def job_template
    job_template = var_search(@handle.object, 'job_template') || job_template_by_name || job_template_by_id

    if job_template.nil?
      @handle.log(:error, "Job Template not specified")
      exit(MIQ_ERROR)
    end
    job_template
  end

  def job_template_by_name
    name = var_search(@handle.object, 'job_template_name') ||
           var_search(@handle.object, 'dialog_job_template_name')
    @handle.vmdb(SCRIPT_CLASS).where('lower(name) = ?', name.downcase).first if name
  end

  def job_template_by_id
    job_template_id = var_search(@handle.object, 'job_template_id') ||
                      var_search(@handle.object, 'dialog_job_template_id')
    @handle.vmdb(SCRIPT_CLASS).where(:id => job_template_id).first if job_template_id
  end

  def extra_variables
    ansible_vars(@handle.object, {})
  end

  def run(job_template, target)
    @handle.log(:info, "Processing Job Template #{job_template.name}")
    args = {:extra_vars => extra_variables}
    args[:limit] = target if target
    @handle.log(:info, "Job Arguments #{args}")

    job = @handle.vmdb(JOB_CLASS).create_job(job_template, args)

    @handle.log(:info, "Scheduled Job ID: #{job.id} Ansible Job ID: #{job.ems_ref}")
    @handle.set_state_var(:ansible_job_id, job.id)
  end
end

if __FILE__ == $PROGRAM_NAME
  LaunchAnsibleJob.new($evm).main
end
