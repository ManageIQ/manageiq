class VmdbTableEvm < VmdbTable
  has_many :text_tables, :class_name => "VmdbTableText", :foreign_key => :parent_id, :dependent => :destroy

  include_concern 'VmdbTableEvm::MetricCapture'
  include_concern 'Seeding'
end
