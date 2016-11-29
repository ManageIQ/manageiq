module DatawarehouseSummaryHelper
  include TextualMixins::TextualName

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_nativeid
    @record.nativeid
  end

  def textual_group_smart_management
    %i(tags)
  end
end
