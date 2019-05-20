# Create a small environment for Redhat
FactoryBot.define do
  factory :environment_redhat, class: OpenStruct do
    zone { FactoryBot.build(:zone) }
    ems  { FactoryBot.build(:ems_redhat, :zone => zone, :api_version => '4.2.4') }

    transient do
      with_host { true }
      with_vm { true }
    end

    host { FactoryBot.build(:host_redhat, :ext_management_system => ems) if with_host }
    vm { FactoryBot.build(:vm_redhat, :ext_management_system => ems) if with_vm }
  end
end
