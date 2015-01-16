class RemoveCustomFieldsFromVmsHosts < ActiveRecord::Migration
  class CustomAttribute < ActiveRecord::Base
    belongs_to :resource, :polymorphic => true      # TODO: figure out which model is used: nested or global model?
  end
  class Host < ActiveRecord::Base; end
  class Vm < ActiveRecord::Base; end

  def self.up
    # Add source column and mark all existing rows as VC data
    add_column :custom_attributes, :source, :string
    say_with_time("Update CustomAttribute source to VC") do
      CustomAttribute.select('id, source').each {|ca| ca.update_attribute('source', 'VC')}
    end

    custom_names = (1..9).collect {|i| "custom_#{i}"}
    move_custom_vars(Vm,   custom_names)
    move_custom_vars(Host, custom_names)

    [:vms, :hosts].each {|klass| custom_names.each {|cn| remove_column klass  , cn.to_sym}}
  end

  def self.down
    custom_names = (1..9).collect {|i| "custom_#{i}"}
    [:vms, :hosts].each {|klass| custom_names.each {|cn| add_column klass, cn.to_sym, :string}}

    say_with_time("Migrate CustomAttribute to resource custom columns") do
      ca = CustomAttribute.where("source = 'EVM' AND name like 'custom_%'").includes(:resource)
      ca.each {|c| c.resource.update_attribute(c.name, c.value) if c.name =~ /^custom_[1-9]$/}
    end

    say_with_time("Remove non-VC CustomAttributes") do
      deletes = CustomAttribute.select('id').where("source != 'VC'")
      CustomAttribute.delete(deletes.collect{|ca| ca.id})
    end
    remove_column :custom_attributes, :source
  end

  def self.move_custom_vars(klass, custom_names)
    say_with_time("Migrate #{klass.name} custom columns to CustomAttribute") do
      condition = (custom_names).join(' is not NULL OR ') +  ' is not NULL'
      items = klass.select(custom_names + ['id']).where(condition)

      custom_attrs = []
      res_type = klass.name
      items.each do |vm|
        res_id = vm.id
        vm.attributes.each do |k, v|
          custom_attrs << {:name=>k, :value=>v, :resource_type=>res_type, :resource_id=>res_id, :source=>'EVM'} unless k=='id' || v.blank?
        end
      end
      CustomAttribute.create(custom_attrs)
    end
  end
end
