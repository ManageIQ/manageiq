class ConvertSmisClassHierToString < ActiveRecord::Migration
  class MiqCimInstance < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def self.up
    say_with_time("Migrate MiqCimInstance class_hier") do
      MiqCimInstance.all.each do |ci|
        cia = YAML.load(ci.class_hier)
        cis = '/' + cia.join('/') + '/'
        ci.update_attribute :class_hier, cis
      end
    end

    change_column :miq_cim_instances, :class_hier, :string, :limit => 1024
  end

  def self.down
    change_column :miq_cim_instances, :class_hier, :text

    say_with_time("Migrate MiqCimInstance class_hier") do
      MiqCimInstance.all.each do |ci|
        cia = YAML.dump(ci.class_hier[1..-2].split('/'))
        ci.update_attribute :class_hier, cia
      end
    end
  end
end
