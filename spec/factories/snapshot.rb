FactoryBot.define do
  # Note that in practice you will need to call EvmSpecHelper.local_miq_server
  # before attempting to create a snapshot factory. This is so that a valid EMS
  # and zone exist for the on_create callback in the Snapshot model.
  factory :snapshot do
    vm_or_template { create(:vm_vmware) }
    create_time { 1.minute.ago }
  end
end
