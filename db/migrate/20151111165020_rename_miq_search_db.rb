class RenameMiqSearchDb < ActiveRecord::Migration
  class MiqSearch < ActiveRecord::Base; end

  NAME_HASH = Hash[*%w(
    TemplateInfra ManageIQ::Providers::InfraManager::Template
    VmInfra       ManageIQ::Providers::InfraManager::Vm
    TemplateCloud ManageIQ::Providers::CloudManager::Template
    VmCloud       ManageIQ::Providers::CloudManager::Vm
  )]

  def up
    say_with_time("Rename MiqSearch db values") do
      MiqSearch.all.each do |search|
        search.update_attributes!(:db => NAME_HASH[search.db]) if NAME_HASH.key?(search.db)
      end
    end
  end
end
