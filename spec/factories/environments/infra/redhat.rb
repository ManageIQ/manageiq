# Create a small test environment for Redhat. This will build an EMS with
# an associated zone, and attach a number of other resources depending on
# the options passed to the Factory builder.
#
# Example:
#
# env = FactoryBot.build(:environment_infra_redhat, :num_host => 2, :num_vm => 4)
#
# env.ems.hosts
# env.ems.vms
#
# The possible options are:
#
# # num_cluster # => default: 2
# * num_host    # => default: 2 per cluster
# * num_vm      # => default: 2 per cluster
#
FactoryBot.define do
  factory :environment_infra_redhat, class: OpenStruct do
    zone { FactoryBot.build(:zone) }
    ems  { FactoryBot.build(:ems_redhat, :zone => zone, :api_version => '4.2.4') }

    transient do
      num_cluster { 2 }
      num_host    { 2 }
      num_vm      { 2 }
    end

    # TODO: This isn't working, the associations are not preserved for some reason.
    #
    after(:build) do |env, evaluator|
      FactoryBot.build_list(:ems_cluster, evaluator.num_cluster, :ext_management_system => env.ems)

      env.ems.ems_clusters.each do |cluster|
        FactoryBot.build_list(:vm_redhat, evaluator.num_vm, :ems_cluster => cluster)
        FactoryBot.build_list(:vm_redhat, evaluator.num_hosts, :ems_cluster => cluster)
      end
    end
  end
end
