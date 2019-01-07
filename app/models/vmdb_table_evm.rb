class VmdbTableEvm < VmdbTable
  has_many :text_tables, :class_name => "VmdbTableText", :foreign_key => :parent_id # Destroy will be handled by seeder

  include_concern 'VmdbTableEvm::MetricCapture'
end
