module CatalogHelper::TextualSummary
  def textual_tags
    label = _("%{name} Tags") % {:name => session[:customer_name]}
    h = {:label => label}
    if @record.tags.blank?
      h[:image] = "smarttag"
      h[:value] = _("No %{label} have been assigned") % {:label => label}
    else
      h[:value] = []
      @record.tags.each do |tag|
        values = tag.name.split('/')
        p = h[:value].find { |x| x[:label] == values[2].humanize}
        if p.present?
          p[:value].push(values[3].humanize)
        else
          h[:value].push({:image => "smarttag", :label => values[2].humanize, :value => [values[3].humanize]})
        end
      end
    end
    binding.pry
    h
  end

  def textual_group_smart_management
    %i(tags)
  end
end
