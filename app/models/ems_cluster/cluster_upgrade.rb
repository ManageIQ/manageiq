# This module should not really exist, upgrade_cluster should be implamented
# for a specific provider using STI, but that could not be backported. It should
# move to the RHV provider when STI is added.
module EmsCluster::ClusterUpgrade
  extend ActiveSupport::Concern

  included do
    supports :upgrade_cluster do
      unsupported_reason_add(:upgrade_cluster, "Only supported for RHV Clusters") unless ext_management_system.emstype == "rhevm"
    end
  end

  def upgrade_cluster(ansible_extra_vars = {}, job_timeout = 1.year)
    role_options = {:role_name => "oVirt.cluster-upgrade"}
    job = ManageIQ::Providers::Redhat::AnsibleRoleWorkflow.create_job({}, extra_vars_for_upgrade(ansible_extra_vars), role_options, :timeout => job_timeout)
    job.signal(:start)
    job.miq_task
  end

  def extra_vars_for_upgrade(options = {})
    connect_options = ext_management_system.apply_connection_options_defaults(options)

    url = URI::Generic.build(
      :scheme => connect_options[:scheme],
      :host   => connect_options[:server],
      :port   => connect_options[:port],
      :path   => connect_options[:path]
    ).to_s

    {
      :engine_url      => url,
      :engine_user     => connect_options[:username],
      :engine_password => connect_options[:password],
      :cluster_name    => name,
      :hostname        => "localhost",
      :ca_string       => connect_options[:ca_certs]
    }.compact
  end
end
