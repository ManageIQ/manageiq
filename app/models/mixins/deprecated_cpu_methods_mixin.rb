module DeprecatedCpuMethodsMixin
  def self.included(base)
    base.send(:alias_method, :cores_per_socket, :cpu_cores_per_socket)
    base.virtual_column(:cores_per_socket, :type => :integer, :uses => :hardware)
    Vmdb::Deprecation.deprecate_methods(base, :cores_per_socket => :cpu_cores_per_socket)
  end
end
