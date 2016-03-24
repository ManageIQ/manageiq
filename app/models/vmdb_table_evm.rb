class VmdbTableEvm < VmdbTable
  has_many :text_tables, :class_name => "VmdbTableText", :foreign_key => :parent_id, :dependent => :destroy

  include_concern 'VmdbTableEvm::MetricCapture'
  include_concern 'Seeding'

  def sql_indexes
    actual  = self.class.connection.indexes(name)
    pk = self.class.connection.primary_key_index(name)
    actual << pk if pk
    actual
  end
end
