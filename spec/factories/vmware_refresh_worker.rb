FactoryGirl.define do
  factory :vmware_refresh_worker, :class => 'ManageIQ::Providers::Vmware::InfraManager::RefreshWorker' do
    pid { Process.pid }
  end
end
