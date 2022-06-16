ServiceAwx.include(ActsAsStiLeafClass)

class ServiceAnsibleTower < ServiceAwx
  def launch_job
    job_class = "#{job_template.class.module_parent.name}::#{job_template.class.stack_type}".constantize
    options = job_options.with_indifferent_access.deep_merge(
      :extra_vars => {
        'manageiq'            => service_manageiq_env,
        'manageiq_connection' => manageiq_connection_env(evm_owner)
      }
    )
    _log.info("Launching Ansible Tower job with options:")
    $log.log_hashes(options, :filter => ["api_token", "token"])
    @job = job_class.create_job(job_template, options)
    add_resource(@job)
    @job
  ensure
    # create options may never be saved before unless they were overridden
    save_launch_options
  end
end
