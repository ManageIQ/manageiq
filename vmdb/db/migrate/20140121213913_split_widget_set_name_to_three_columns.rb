class SplitWidgetSetNameToThreeColumns < ActiveRecord::Migration
  class MiqSet < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :miq_sets, :userid,  :string
    add_column :miq_sets, :group_id, :bigint

    say_with_time("Splitting name column for MiqWidgetSet") do
      MiqSet.where(:set_type => 'MiqWidgetSet').each do |ws|
        next unless ws.name.include?("|")
        items = ws.name.split("|")
        if items.size == 3
          userid, group_id, name = items
          ws.update_attributes(:name => name, :userid => userid, :group_id => group_id)
        else
          ws.destroy
        end
      end
    end

    add_index :miq_sets, :userid
    add_index :miq_sets, :group_id
  end

  def down
    MiqSet.where(:set_type => 'MiqWidgetSet').each do |ws|
      next if ws.userid.nil? || ws.group_id.nil?
      name = "#{ws.userid}|#{ws.group_id}|#{ws.name}"
      ws.update_attributes(:name => name)
    end

    remove_index  :miq_sets, :userid
    remove_index  :miq_sets, :group_id
    remove_column :miq_sets, :userid
    remove_column :miq_sets, :group_id
  end
end
