module TextualMixins::TextualEmsCloud
  def textual_ems_cloud
    textual_link(@record.ext_management_system)
  end
end
