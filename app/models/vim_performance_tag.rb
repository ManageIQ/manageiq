class VimPerformanceTag < MetricRollup
  def self.instances_are_derived?
    true
  end

  def self.find_entries(_ext_options = {})
    # noop - just return default scope (will be chained from here)
    self
  end

  def self.find_and_group_by_tags(options)
    group_by_tags(find_entries(options[:ext_options]).where(options[:where_clause]), options)
  end

  def self.group_by_tags(recs, options)
    raise _("no category provided") if options[:category].blank?
    raise _("option :cat_model must have a value") unless options[:cat_model]
    cat_assoc = Object.const_get(options[:cat_model].to_s).table_name.to_sym
    tp = options.fetch_path(:ext_options, :time_profile)
    results = recs.inject(:res => [], :tags => [], :tcols => []) do |h, rec|
      tvrecs = build_tag_value_recs(rec, options)
      if rec.class.name == "VimPerformanceTag"
        rec.inside_time_profile = tp ? tp.ts_in_profile?(rec.timestamp) : true
      else
        rec.inside_time_profile = tp ? tp.ts_day_in_profile?(rec.timestamp) : true
      end

      tvrecs.each do |tv|
        if  rec.inside_time_profile == false
          tv.value = tv.assoc_ids = nil
          _log.debug("Timestamp: [#{rec.timestamp}] is outside of time profile")
        else
          tv.value ||= 0
        end
        c = [tv.column_name, tv.tag_name].join("_").to_sym
        rec.class.class_eval("attr_accessor #{c.inspect}")
        rec.send(c.to_s + "=", tv.column_name == "assoc_ids" ? tv.assoc_ids : tv.value)
        h[:tags].push(tv.tag_name).uniq!
        h[:tcols].push(c.to_s).uniq!
      end

      h[:res].push(rec)
      h
    end

    results[:res].each do |rec|
      # Default nil values in tag cols to 0 for records with timestamp that falls inside the time profile
      results[:tcols].each { |c| rec.send("#{c}=", 0) if rec.send(c).nil? } if rec.inside_time_profile == true

      # Fill in missing assos ids
      fill_assoc_ids(rec.timestamp, rec, cat_assoc, results[:tags])
    end

    return results[:res], results[:tcols].sort, results[:tags].sort
  end

  def self.build_tag_value_recs(rec, options)
    tvrecs = VimPerformanceTagValue.build_for_association(rec,
                                                          options[:cat_model].pluralize.underscore,
                                                          :category => options[:category])
    tvrecs = tvrecs.select { |r| r.category == options[:category] }

    if tvrecs.empty?
      tvrecs = VimPerformanceTagValue.tag_cols(rec.resource_type).inject([]) do |arr, c|
        trec = VimPerformanceTagValue.new(:column_name => c, :tag_name => "_none_")
        c == "assoc_ids" ? trec.assoc_ids = rec.send(c) : trec.value = rec.send(c)
        arr << trec
      end
    end

    tvrecs
  end

  def self.fill_assoc_ids(_ts, result, assoc, tags)
    tags.each do |t|
      assoc_ids_meth = ["assoc_ids", t].join("_").to_s
      if result.send(assoc_ids_meth).nil?
        result.send("#{assoc_ids_meth}=", assoc => {:on => []})
      end
    end
  end
end
