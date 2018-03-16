require 'yaml'

module ScanningOperationsMixin
  include Vmdb::Logging

  def save_metadata_op(xmlFile, type, jobid = nil)
    _log.info("target [#{guid}],  job [#{jobid}] enter")
    _log.info("target [#{guid}] found target object id [#{id}], job [#{jobid}]")
    MiqQueue.submit_job(
      :service     => "smartstate",
      :affinity    => ext_management_system,
      :target_id   => id,
      :class_name  => self.class.base_class.name,
      :method_name => "save_metadata",
      :data        => Marshal.dump([xmlFile, type]),
      :task_id     => jobid,
    )
    _log.info("target [#{guid}] data put on queue, job [#{jobid}]")
    true
  rescue StandardError => err
    _log.log_backtrace(err)
    false
  end
end
