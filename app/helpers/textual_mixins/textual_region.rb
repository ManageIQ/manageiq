module TextualMixins::TextualRegion
  def textual_region
    return nil if @record.region_number == MiqRegion.my_region_number
    h = {:label => _("Region")}
    reg = @record.miq_region
    url = reg.remote_ui_url
    h[:value] = if url
                  # TODO: Why is this link different than the others?
                  link_to(reg.description, url_for(:host   => url,
                                                   :action => 'show',
                                                   :id     => @record),
                          :title   => _("Connect to this VM in its Region"),
                          :onclick => "return miqClickAndPop(this);")
                else
                  reg.description
                end
    h
  end
end
