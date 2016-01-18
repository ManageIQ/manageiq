module ChargebackHelper
  def chargeback_details_groups(chargeback_details)
    groups = Hash.new
    chargeback_details.each_with_index do |r|
      new_group = Dictionary.gettext(r[:group], :type => :rate_detail_group, :notfound => :titleize)
      groups[new_group] = r[:group] unless groups.has_key?(new_group)
    end
    groups
  end
  def chargeback_details_metrics(chargeback_details, group)
    metrics = Hash.new
    chargeback_details.each_with_index do |r|
      if r[:metric].nil? then r[:metric] = r[:description] end
      metrics[r[:description]] = r[:metric] unless r[:group] != group and (r[:rate] != "0" || r[:rate] != "")
    end
    metrics
  end

  def get_valids_columns()
     hash_columns = { :start_date               => :datetime,
                      :end_date                 => :datetime,
                      :interval_name            => :string,
                      :display_range            => :string,
                      :vm_name                  => :string,
                      :owner_name               => :string
                    }
     ChargebackRate.where( :default => true ).each do |cb|
       cb.chargeback_rate_details.where.not(:rate => "0").each do |rd|
         column = rd.group+"_"+rd.source
         if rd.group != "fixed"
           hash_columns = hash_columns.merge((column + "_metric").to_sym => :float, (column + "_cost").to_sym => :float)
           hash_columns = hash_columns.merge((rd.group + "_metric").to_sym => :float, (rd.group + "_cost").to_sym => :float)
         else
           hash_columns = hash_columns.merge((column + "_cost").to_sym => :float)
           hash_columns = hash_columns.merge((rd.group + "_cost").to_sym => :float)
         end
       end
     end
     hash_columns = hash_columns.merge(:total_cost => :float)
     hash_columns
  end
end
