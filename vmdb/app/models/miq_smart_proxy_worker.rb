class MiqSmartProxyWorker < MiqQueueWorkerBase
  self.required_roles       = ["smartproxy"]
  self.default_queue_name   = "smartproxy"

  def self.build_command_line(*params)
    vix_library_path = "LD_LIBRARY_PATH=\"${LD_LIBRARY_PATH}:#{Rails.root.join("..", "lib", "VixDiskLib", "vddklib")}\""

    MiqEnvironment::Command.is_appliance? ? "#{vix_library_path} #{super}" : super
  end
end
