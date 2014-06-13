class AddOrderToDialogResources < ActiveRecord::Migration

  class DialogResource < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Dialog < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class DialogTab < ActiveRecord::Base
    belongs_to :dialog
    self.inheritance_column = :_type_disabled # disable STI
  end

  class DialogGroup < ActiveRecord::Base
    belongs_to :dialog_tab
    self.inheritance_column = :_type_disabled # disable STI
  end

  class DialogField < ActiveRecord::Base
    belongs_to :dialog_group
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :dialog_tabs,   :dialog_id,       :bigint
    add_column :dialog_tabs,   :order,           :int

    add_column :dialog_groups, :dialog_tab_id,   :bigint
    add_column :dialog_groups, :order,           :int

    add_column :dialog_fields, :dialog_group_id, :bigint
    add_column :dialog_fields, :order,           :int

    say_with_time("Migrating dialog order from join-table to model") do
      DialogResource.all.each do |dr|
        resource = AddOrderToDialogResources.const_get(dr.resource_type).find_by_id(dr.resource_id)
        next if resource.nil?

        parent_key = "#{dr.parent_type.underscore}_id"
        resource.update_attributes!(:order => dr.order, parent_key => dr.parent_id)
      end
    end

    drop_table :dialog_resources
  end

  def down
    create_table :dialog_resources do |t|
      t.belongs_to  :parent,      :polymorphic => true
      t.belongs_to  :resource,    :polymorphic => true
      t.integer     :order
    end

    say_with_time("Migrating dialog order from model to join-table") do
      [["DialogTab", "dialog"], ["DialogGroup", "dialog_tab"], ["DialogField", "dialog_group"]].each do |klass, parent_key|
        AddOrderToDialogResources.const_get(klass).all.each do |resource|
          parent_id = resource.send("#{parent_key}_id")
          next if parent_id.blank?
          DialogResource.create(:parent_type   => parent_key.classify, :parent_id   => parent_id,
                                :resource_type => klass,               :resource_id => resource.id,
                                :order => resource.order)
        end
      end
    end

    remove_column :dialog_tabs,   :dialog_id
    remove_column :dialog_tabs,   :order

    remove_column :dialog_groups, :dialog_tab_id
    remove_column :dialog_groups, :order

    remove_column :dialog_fields, :dialog_group_id
    remove_column :dialog_fields, :order
  end

end