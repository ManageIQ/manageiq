class AddReportRowsPerDetailRowsToMiqReportResults < ActiveRecord::Migration
  def self.up
    add_column    :miq_report_results,  :report_rows_per_detail_row,  :integer
  end

  def self.down
    remove_column :miq_report_results,  :report_rows_per_detail_row
  end
end
