class VmdbTableText < VmdbTable
  belongs_to :evm_table, :class_name => "VmdbTableEvm", :foreign_key => :parent_id

  include_concern 'Seeding'

  def sql_indexes
    self.class.connection.respond_to?(:text_table_indexes) ? self.class.connection.text_table_indexes(self.name) : []
  end

  def capture_metrics
    # TODO:
  end
end
