class AddIndexToMiqReportResultDetails < ActiveRecord::Migration
  def self.up
    add_index    :miq_report_result_details, [:miq_report_result_id, :data_type, :id], :name => "miq_report_result_details_idx"
  end

  def self.down
    remove_index :miq_report_result_details, :name => "miq_report_result_details_idx"
  end
end
