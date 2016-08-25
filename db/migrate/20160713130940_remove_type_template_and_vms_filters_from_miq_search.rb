class RemoveTypeTemplateAndVmsFiltersFromMiqSearch < ActiveRecord::Migration[5.0]
  class MiqSearch < ActiveRecord::Base
    serialize :filter
  end

  TEMPLATE_FITLER_EXPR = MiqExpression.new("=" => {"field" => "VmInfra-template", "value" => "true"})
  TEMPLATE_TYPE_FILTER = {:name => "default_Type / Template", :description => "Type / Template",
                          :filter => TEMPLATE_FITLER_EXPR, :search_type => "default",
                          :db => "ManageIQ::Providers::InfraManager::Vm"}.freeze

  VMS_FITLER_EXPR = MiqExpression.new("not" => {"ENDS WITH" => {"field" => "VmInfra-location", "value" => ".vmtx"}})
  VMS_TYPE_FILTER = {:name => "default_Type / VM", :description => "Type / VM", :filter => VMS_FITLER_EXPR,
                     :search_type => "default", :db => "ManageIQ::Providers::InfraManager::Vm"}.freeze

  def up
    say_with_time('Remove Type / Template and Type / VM from VMs filters') do
      template_filter = TEMPLATE_TYPE_FILTER.dup
      template_filter.except!(:filter, :search_type)
      MiqSearch.where(template_filter).delete_all

      vms_filter = VMS_TYPE_FILTER.dup
      vms_filter.except!(:filter, :search_type)
      MiqSearch.where(vms_filter).delete_all
    end
  end

  def down
    say_with_time('Add Type / Template and Type / VM to VMs filters') do
      MiqSearch.create!(TEMPLATE_TYPE_FILTER)
      MiqSearch.create!(VMS_TYPE_FILTER)
    end
  end
end
