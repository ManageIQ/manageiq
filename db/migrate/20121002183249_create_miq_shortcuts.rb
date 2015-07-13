class CreateMiqShortcuts < ActiveRecord::Migration
  def change
    create_table :miq_shortcuts do |t|
      t.string     :name
      t.string     :description
      t.string     :url
      t.string     :rbac_feature_name
      t.boolean    :startup
    end

    create_table :miq_widget_shortcuts do |t|
      t.string     :description
      t.belongs_to :miq_shortcut, :type => :bigint
      t.belongs_to :miq_widget,   :type => :bigint
    end
  end
end
