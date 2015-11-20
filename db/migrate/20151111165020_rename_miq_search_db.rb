class RenameMiqSearchDb < ActiveRecord::Migration
  class MiqSearch < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  NAME_HASH = Hash[*%w(
    TemplateInfra ManageIQ::Providers::InfraManager::Template
    VmInfra       ManageIQ::Providers::InfraManager::Vm
    TemplateCloud ManageIQ::Providers::CloudManager::Template
    VmCloud       ManageIQ::Providers::CloudManager::Vm
  )]

  def change
    MiqSearch.all.each do |search|
      search.db = NAME_HASH[search.db] if NAME_HASH.key?(search.db)
      search.save!
    end
  end
end
