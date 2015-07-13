class AddTypeToMiqCimStat < ActiveRecord::Migration
  class MiqCimStat < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def self.up
    add_column :miq_cim_stats, :type, :string
    say_with_time("Update MiqCimStat type to MiqCimStat") do
      MiqCimStat.update_all(:type => "MiqCimStat")
    end
  end

  def self.down
    remove_column :miq_cim_stats, :type
  end
end
