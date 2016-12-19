module TextualMixins::TextualInitProcesses
  def textual_init_processes
    os = @record.os_image_name.downcase
    return nil unless os =~ /linux/
    num = @record.number_of(:linux_initprocesses)
    # TODO: Why is this image different than graphical?
    h = {:label => _("Init Processes"), :icon => "fa fa-cog", :value => num}
    if num > 0
      h[:title] = n_("Show the Init Process installed on this VM", "Show the Init Processes installed on this VM", num)
      h[:explorer] = true
      h[:link] = url_for(:controller => controller.controller_name, :action => 'linux_initprocesses', :id => @record)
    end
    h
  end
end
