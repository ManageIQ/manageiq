class CreateMiqWidgetContents < ActiveRecord::Migration
  def self.up
    create_table :miq_widget_contents do |t|
      t.bigint    :miq_widget_id
      t.bigint    :miq_report_result_id
      t.bigint    :user_id
      t.text      :contents

      t.timestamps
    end
  end

  def self.down
    drop_table :miq_widget_contents
  end
end
