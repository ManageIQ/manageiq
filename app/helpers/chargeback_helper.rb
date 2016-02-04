module ChargebackHelper
  def chargeback_details_groups(chargeback_details)
    groups = {}
    chargeback_details.each do |r|
      new_group = Dictionary.gettext(r[:group], :type => :rate_detail_group, :notfound => :titleize)
      groups[new_group] = r[:group] unless groups.key?(new_group)
    end
    groups
  end

  def chargeback_details_metrics(chargeback_details, group)
    metrics = {}
    chargeback_details.each do |r|
      if r[:metric].nil? then r[:metric] = r[:description] end
      metrics[r[:description]] = r[:metric] unless r[:group] != group && (r[:rate] != "0" || r[:rate] != "")
    end
    metrics
  end
end
