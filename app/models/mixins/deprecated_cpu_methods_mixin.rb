module DeprecatedCpuMethodsMixin
  def self.included(base)
    {:cores_per_socket => :cpu_cores_per_socket, :logical_cpus => :cpu_total_cores}.each do |k, v|
      base.send(:alias_method, k, v)
      base.virtual_column(k, :type => :integer, :uses => :hardware)
      Vmdb::Deprecation.deprecate_methods(base, k => v)
    end
  end
end
