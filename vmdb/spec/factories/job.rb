FactoryGirl.define do
  factory :scan_job, :class => :Job do
    type            "VmScan"
    state           "waiting_to_start"
    status          "ok"
    dispatch_status "pending"
    target_class    "Vm"
  end
end
