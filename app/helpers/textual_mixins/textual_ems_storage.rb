module TextualMixins::TextualEmsStorage
  def textual_ems_storage
    textual_link(@record.ext_management_system)
  end
end
