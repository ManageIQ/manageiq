class VmdbTableEvm < VmdbTable
  has_many :text_tables, :class_name => "VmdbTableText", :foreign_key => :parent_id, :dependent => :destroy

  include_concern 'VmdbTableEvm::MetricCapture'
  include_concern 'Seeding'

  def sql_indexes
    actual  = self.class.connection.indexes(self.name)
    actual += self.class.connection.respond_to?(:primary_key_indexes) ? self.class.connection.primary_key_indexes(self.name) : []
    actual
  end
end
