class CreateMiqReportResultDetails < ActiveRecord::Migration
  def self.up
    create_table :miq_report_result_details do |t|
      t.column  :miq_report_result_id,      :integer
      t.column  :data_type,                 :string
      t.column  :data,                      :text
    end

    add_column  :miq_report_results,  :last_accessed_on,  :timestamp
  end

  def self.down
    remove_column  :miq_report_results,  :last_accessed_on
    drop_table     :miq_report_result_details
  end
end
