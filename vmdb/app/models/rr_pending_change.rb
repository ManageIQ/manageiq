class RrPendingChange < ActiveRecord::Base
  RR_TABLE_NAME_SUFFIX = "pending_changes"
  include RrModelCore

  def self.last_id
    # PostgreSQL specific
    # We can't just use MAX(id) because the rows may be deleted
    raise ActiveRecord::StatementInvalid, "PGError: ERROR:  relation \"#{table_name}\" does not exist" unless table_exists?
    details = connection.sequence_details(connection.primary_key_sequence(table_name))
    is_called = VirtualColumn.new("is_called", :type => :boolean).type_cast(details["is_called"])
    is_called ? details["last_value"].to_i : details["start_value"].to_i - 1
  end

  class << self; alias backlog count; end

  def self.backlog_details
    counts = self.all(
      :select => "change_table, COUNT(id) AS count_all",
      :group  => "change_table"
    )
    counts.each_with_object({}) { |c, h| h[c.change_table] = c.count_all.to_i }
  end
end
