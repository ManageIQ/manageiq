# Create a small test environment for Redhat. This will create an EMS with
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
# * num_host # => default: 1
# * num_vm   # => default: 1
#
FactoryBot.define do
  factory :environment_infra_redhat, class: OpenStruct do
    zone { FactoryBot.build(:zone) }
    ems  { FactoryBot.build(:ems_redhat, :zone => zone, :api_version => '4.2.4') }

    transient do
      num_host { 1 }
      num_vm   { 1 }
    end

    after(:build) do |env, evaluator|
      env.ems.hosts = FactoryBot.build_list(:host_redhat, evaluator.num_host)
      env.ems.vms = FactoryBot.build_list(:vm_redhat, evaluator.num_vm)
    end
  end
end
