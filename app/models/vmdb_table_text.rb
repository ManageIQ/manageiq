class VmdbTableText < VmdbTable
  belongs_to :evm_table, :class_name => "VmdbTableEvm", :foreign_key => :parent_id

  def capture_metrics
    # TODO:
  end
end
