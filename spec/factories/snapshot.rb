FactoryGirl.define do
  factory :snapshot do
    vm_or_template { create(:vm_vmware) }
    create_time { 1.minute.ago }
  end
end
