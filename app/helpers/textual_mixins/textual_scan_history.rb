module TextualMixins::TextualScanHistory
  def textual_scan_history
    h = {:label => _("Analysis History"), :image => "100/scan.png"}
    num = @record.number_of(:scan_histories)
    if num == 0
      h[:value] = _("None")
    else
      h[:value] = num
      h[:title] = _("Show virtual machine analysis history")
      h[:explorer] = true
      h[:link] = url_for(:controller => controller.controller_name, :action => 'scan_histories', :id => @record)
    end
    h
  end
end
