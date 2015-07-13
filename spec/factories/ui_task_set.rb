FactoryGirl.define do
  factory :ui_task_set do
  end

  factory :ui_task_set_admin, :class => :UiTaskSet do
    name         "super_administrator"
    description  "Super Administrator"
  end

  factory :ui_task_set_approver, :class => :UiTaskSet do
    name         "approver"
    description  "Approver"
  end
end
