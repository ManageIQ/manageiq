module MiqReport::Generator::Aggregation
  def build_subtotals(all_dims = false)
    return unless group == "c" || (!col_options.blank? && col_options.any? { |_c, h| h.key?(:grouping) })
    return if     sortby.blank?

    grouping_keys = all_dims ? sortby : sortby.first
    extras[:grouping] = generate_subtotals(table, grouping_keys, col_options)
  end

  def generate_subtotals(table, group_keys, options)
    gkeys  = group_keys.kind_of?(String) ? group_keys.lines : Array.wrap(group_keys)
    totals = {:count => 0, :row => {}}
    group  = {:count => 0, :row => {}}
    result = {}
    gid = nil
    table.each do |r|
      if gid != get_group_val(r, gkeys)
        process_group_break(gid, group, totals, result) unless gid.nil?
        group = {:count => 0, :row => r.to_hash}
        gid = get_group_val(r, gkeys)
      end
      aggregate_totals(r, group, totals, options)
      group[:count] += 1
    end
    process_group_break(gid, group, totals, result)
    process_totals(totals)
    result[:_total_] = totals
    result
  end

  def aggregate_totals(row, group, total, options)
    return if options.blank?

    options.each_key do |c|
      grouping = options[c][:grouping]
      next unless grouping

      val = row[c].to_f
      grouping.each do |g|
        group[g] ||= {}
        total[g] ||= {}
        group[g][c] ||= 0 unless g == :min
        total[g][c] ||= 0 unless g == :min
        case g
        when :avg, :total
          group[g][c] += val
          total[g][c] += val
        when :min
          group[g][c] = val if group[g][c].nil? || val < group[g][c]
          total[g][c] = val if total[g][c].nil? || val < total[g][c]
        when :max
          group[g][c] = val if val > group[g][c]
          total[g][c] = val if val > total[g][c]
        end
      end
    end
  end

  def process_totals(group)
    group.each_key do |g|
      next if g == :count
      group[g].each_key do |c|
        case g
        when :total, :count, :min, :max
        when :avg
          group[g][c] = group[g][c] / group[:count].to_f if group[:count]
        end
      end
    end
  end
end
