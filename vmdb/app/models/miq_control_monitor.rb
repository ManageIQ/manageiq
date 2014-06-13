class MiqControlMonitor < MiqWorker
  include PerEmsWorkerMixin

  self.required_roles = ["control"]

  def self.ems_class
    EmsVmware
  end

  def friendly_name
    @friendly_name ||= begin
      ems = self.ext_management_system
      name = ems.nil? ? self.queue_name.titleize : "#{ui_lookup(:table=>"ext_management_systems")}: #{ems.name} Control Monitor"
      "#{name} (#{self.pid})"
    end
  end
end
