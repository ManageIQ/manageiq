class AddGroupAndUserColumnsToMiqWidgetContents < ActiveRecord::Migration
  class MiqWidgetContent < ActiveRecord::Base; end

  def up
    add_column    :miq_widget_contents, :miq_group_id, :bigint
    add_column    :miq_widget_contents, :user_id,      :bigint
    add_index     :miq_widget_contents, :user_id
    remove_index  :miq_widget_contents, :owner_id
    remove_column :miq_widget_contents, :owner_type
    remove_column :miq_widget_contents, :owner_id

    say_with_time "Remove all existing widget content" do
      MiqWidgetContent.delete_all
    end
  end

  def down
    add_column    :miq_widget_contents, :owner_type, :string
    add_column    :miq_widget_contents, :owner_id,   :bigint
    add_index     :miq_widget_contents, :owner_id
    remove_index  :miq_widget_contents, :user_id
    remove_column :miq_widget_contents, :miq_group_id
    remove_column :miq_widget_contents, :user_id

    say_with_time "Remove all existing widget content" do
      MiqWidgetContent.delete_all
    end
  end
end
