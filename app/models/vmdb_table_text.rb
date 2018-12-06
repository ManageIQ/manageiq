class VmdbTableText < VmdbTable
  belongs_to :evm_table, :class_name => "VmdbTableEvm", :foreign_key => :parent_id

  include_concern 'Seeding'


  def capture_metrics
    # TODO:
  end
end
