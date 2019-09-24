class MiqCompare
  include Vmdb::Logging
  EMPTY = '(empty)'
  TAG_PREFIX = '_tag_'

  attr_reader :report
  attr_reader :mode
  attr_reader :ids
  attr_reader :records

  attr_reader :master_list
  attr_reader :results

  attr_accessor :include

  def initialize(options, report)
    options = {:mode => :compare}.merge(options)
    @mode = options[:mode]

    @report = report
    @model = Object.const_get(report.db)

    @include = options.key?(:include) ? options[:include] : self.class.sections(report)

    case @mode
    when :compare
      raise "Must pass at least 2 ids to MiqCompare" if options[:ids].nil? || options[:ids].length < 2

      @ids_orig = options[:ids]
      @ids = Array.new(@ids_orig)
    when :drift
      raise "Must pass at least 2 timestamps to MiqCompare" if options[:timestamps].nil? || options[:timestamps].length < 2
      raise "Must pass an id to MiqCompare" if options[:id].nil?

      @model_record_id = options[:id]
      @ids_orig = options[:timestamps].collect(&:utc)
      @ids = Array.new(@ids_orig)
    else
      raise "Unknown compare type [#{@mode}]"
    end

    get_records
    prepare_master_list

    # Build the results
    @results = {}
    @ids.each { |id| fetch_record(id) }
    @include.each_value { |data| data[:fetched] = data[:fetch] }
  end

  # Adds the specified section to the results, fetching the data if necessary
  def add_section(section)
    return unless @include.key?(section)

    @include[section][:fetch] = @include[section][:checked] = true
    fetch_section(section)
  end

  # Removes the specified section from the results, but retains the fetched data
  def remove_section(section)
    return unless @include.key?(section)

    @include[section][:checked] = false
    calculate_all
  end

  # Adds the record with the specified id to the results
  def add_record(id)
    return if @ids.include?(id)

    @ids_orig << id
    @ids << id
    @records << get_record(id)
    fetch_record(id)
  end

  # Removes the record with the specified id from the results
  def remove_record(id)
    return unless @ids.include?(id)

    is_base = (@ids[0] == id)

    index = @ids.index(id)
    @ids.delete_at(index)
    @records.delete_at(index)

    @ids_orig.delete(id)
    @results.delete(id)

    rebuild_master_list
    calculate_all if is_base || @mode == :drift
  end

  # Sets the record with the specified id as the base record, preserving
  # the order of the original set of ids (or timestamps if in drift mode)
  # passed to MiqCompare.new
  def set_base_record(id)
    return unless @ids[1..-1].include?(id)

    # Sort the records in the original id order
    @records = @ids_orig.collect { |id_orig| @records[@ids.index(id_orig)] }
    @ids = Array.new(@ids_orig)

    # Move the record to the base record
    index = @ids.index(id)
    @ids.unshift(@ids.delete_at(index))
    @records.unshift(@records.delete_at(index))

    calculate_all
  end

  # Retrieve the parts from the master list for a particular section
  def get_master_list_section(section)
    index = @include[section][:master_index]
    @master_list[index..index + 2]
  end

  # Determines whether or not the specified section is a tag section
  def self.tag_section?(section)
    section.to_s[0..TAG_PREFIX.length - 1] == TAG_PREFIX
  end

  # Get the tag name from the specified section
  def self.section_to_tag(section)
    section.to_s[TAG_PREFIX.length..-1]
  end

  # Recursively extracts the set of include sections from the report
  def self.sections(report)
    ret = {}
    build_sections({'include' => report.include}, ret)

    # Also add the default section as checked and to be fetched
    build_section(ret, :_model_, nil, "Properties")
    ret[:_model_][:fetch] = ret[:_model_][:checked] = true

    ret
  end

  private

  # Recursively extract the set of includes by following the 'include' keys,
  # flattening the path as we go.  For example, a 'hardware' section with an
  # 'guest_devices' section below it, would create a 'hardware.guest_devices'
  # section in the resultant include.
  def self.build_sections(section, all_sections, full_name = '')
    return unless section.key?('include') && !section['include'].blank?

    section['include'].each do |name, data|
      group = data['group']

      if name == 'categories'
        data['columns'].each { |c| build_section(all_sections, "#{TAG_PREFIX}#{c}", nil, group) }
      else
        name = "#{full_name}.#{name}" unless full_name.empty?
        if data.key?('key')
          key = data['key'][0]
          key = '' if key.nil?
        else
          key = nil
        end
        build_section(all_sections, name, key, group)
        build_sections(data, all_sections, name)
      end
    end
  end

  private_class_method :build_sections

  # Add an include section to the final collected all_sections hash provided
  def self.build_section(all_sections, name, key = nil, group = nil)
    name = name.to_sym
    all_sections[name] = {:fetch => false, :fetched => false, :checked => false}
    all_sections[name][:key] = key.empty? ? key : key.to_sym unless key.nil?
    all_sections[name][:group] = group unless group.blank?
  end

  def section_header_text(model)
    case model
    when "Host"
      _("Host Properties")
    when "Vm"
      _("VM Properties")
    when "VmOrTemplate"
      _("Workload")
    else
      model.titleize
    end
  end

  private_class_method :build_section

  # Resets the master_list to an initial version without dynamic subsections,
  # nor the tag columns
  def prepare_master_list
    # Prepare the master list based on the report column order
    @master_list = []
    @include.each_value { |data| data.delete(:master_index) }

    @report.col_order.each_with_index do |c, i|
      header = @report.headers[i]

      if @report.cols.include?(c)
        section, column = :_model_, c.to_sym
      else
        # Determine the section and column based on the last '.'
        section, column = $1.to_sym, $2.to_sym if c =~ /(.+)\.([^\.]+)$/
      end

      # See if this section has a key
      if section == :_model_
        section_header = section_header_text(@model.to_s)
        key = nil
      elsif section == :categories
        column = column.to_s
        section = "#{TAG_PREFIX}#{column}".to_sym
        c = Classification.find_by_name(column)
        section_header = (c.nil? || c.description.blank?) ? column.titleize : c.description
        column = nil # columns will be filled in dynamically when we fetch the section data
        key = nil
      else
        section_header = Dictionary.gettext(section.to_s, :type => :table, :notfound => :titleize)
        key = @include[section][:key]
      end

      # Add this section/column to the master list
      unless @include[section].key?(:master_index)
        @include[section][:master_index] = @master_list.length

        @master_list << {:name => section, :header => section_header, :group => @include[section][:group]} << (key.nil? ? nil : []) << []
      end

      # Don't add in any columns that are nil, the key, or start with '_'
      @master_list[@include[section][:master_index] + 2] << {:name => column, :header => header} unless column.nil? || column == key || column.to_s[0, 1] == '_'
    end
  end

  # Rebuilds the master_list from the results
  def rebuild_master_list
    prepare_master_list

    @master_list.each_slice(3) do |section, sub_sections, columns|
      section = section[:name]
      next unless @include[section][:fetched]

      if self.class.tag_section?(section)
        # Get just the tag names from the results
        @results.each_value { |result| columns.concat(result[section].collect { |k, v| k if k.to_s[0, 1] != '_' && v[:_value_] }.compact) }
        columns.uniq!

        # Remove unused tags from the results
        @results.each_value { |result| result[section].delete_if { |k, _v| !columns.include?(k) && k.to_s[0, 1] != '_' } }

        # Get all of the tag headers
        cat = Classification.find_by_name(self.class.section_to_tag(section))
        columns.collect! { |c| {:name => c, :header => cat.find_entry_by_name(c.to_s).description} }

        columns.sort! { |x, y| x[:header].to_s.downcase <=> y[:header].to_s.downcase }
      elsif !sub_sections.nil?
        @results.each_value { |result| sub_sections.concat(result[section].keys.reject { |k| k.to_s[0, 1] == '_' }) }
        sub_sections.uniq! # uniq! returns nil if no action taken, so can't chain with sort
        sub_sections.sort! { |x, y| x.to_s.downcase <=> y.to_s.downcase }
      end
    end
  end

  # Fetch the results from a particular record for all sections marked as
  # :fetch => true in the include
  def fetch_record(id)
    return if @results.key?(id)

    @results[id] = {}
    @master_list.each_slice(3) do |section, sub_sections, columns|
      fetch_record_section(id, section, sub_sections, columns) if @include[section[:name]][:fetch]
    end
    calculate_record(id)
  end

  # Fetch the results from all records for a particular section if marked as
  # :fetch => true
  def fetch_section(section)
    return unless @include[section][:fetch]

    unless @include[section][:fetched]
      section_parts = get_master_list_section(section)
      @ids.each { |id| fetch_record_section(id, *section_parts) }
      @include[section][:fetched] = true
    end
    calculate_all
  end

  # Fetch the results from a particular record for a particular section
  def fetch_record_section(id, section, sub_sections, columns)
    section = section[:name]
    result_section = @results[id][section] = {}
    rec = find_record(id)

    if self.class.tag_section?(section)
      # Build a tag section by storing which tags this record includes
      #   as columns and adding those columns to the master list
      tag_name = self.class.section_to_tag(section)

      # Get the tag entry name and description from the source
      new_columns = case @mode
                    when :compare
                      Classification.find_by_name(tag_name).entries.collect { |e| [e.name, e.description] if rec.is_tagged_with?(e.tag.name, :ns => "*") }
                    when :drift
                      rec.tags.to_miq_a.collect { |tag| [tag.entry_name, tag.entry_description] if tag.category_name == tag_name }
                    end
      new_columns.compact!

      # Add any new columns to the full set of columns
      new_columns.each do |name, header|
        name = name.to_sym
        result_section[name] ||= {}
        result_section[name][:_value_] = true
        columns << {:name => name, :header => header} unless columns.find { |c| c[:name] == name }
      end

      columns.sort! { |x, y| x[:header].to_s.downcase <=> y[:header].to_s.downcase }

      # Complete the tag columns for all other records by filling in default false values
      columns.each do |c|
        c = c[:name]
        @results.each_value do |result|
          if result.key?(section) && !result[section].key?(c)
            result[section][c] ||= {}
            result[section][c][:_value_] = false
          end
        end
      end
    elsif sub_sections.nil?
      # Build a section with no subsections by storing the column values directly
      sub_rec = eval_section(rec, section, id)
      columns.each do |col|
        col = col[:name]
        value = sub_rec && eval_column(sub_rec, col, id)
        value = EMPTY if value.nil?
        result_section[col] = {:_value_ => value}
      end
    else
      # Build a section with subsections by collecting all of the subsections
      #   and storing the columns values under that subsection
      sub_rec = eval_section(rec, section, id)
      unless sub_rec.nil?
        key_name = @include[section][:key]

        # If we do not have a unique key for a record, we provide a running counter instead
        key_counter = 0 if key_name.blank?

        sub_rec.each do |r|
          if key_name.blank?
            key = "\##{key_counter}"
            key_counter += 1
          else
            key = r.send(key_name)
            if key.nil?
              _log.warn("No value was found for the key [#{key_name}] in section [#{section}] for record [#{id}]")
              next
            elsif result_section.key?(key)
              _log.warn("A duplicate key value [#{key}] for the key [#{key_name}] was found in section [#{section}] for record [#{id}]")
              next
            end
          end

          result_section[key] = {}
          columns.each do |col|
            col = col[:name]
            value = r.send(col)
            value = EMPTY if value.nil?
            result_section[key][col] = {:_value_ => value}
          end

          sub_sections << key unless sub_sections.include?(key)
        end

        sub_sections.sort! { |x, y| x.to_s.downcase <=> y.to_s.downcase }
      end
    end
  end

  def eval_section(rec, section, id)
    return rec if section == :_model_
    return nil if rec.nil? || self.class.tag_section?(section)

    section.to_s.split('.').each do |part|
      rec = rec.send(part)
      if rec.nil?
        _log.warn("Unable to evaluate section [#{section}] for record [#{id}], since [.#{part}] returns nil")
        return nil
      end
    end
    rec
  end

  def eval_column(rec, column, id)
    return nil if rec.nil?

    parts = column.to_s.split('.')
    parts.each_with_index do |part, i|
      rec = rec.send(part)
      if rec.nil? && i != (parts.length - 1)
        _log.warn("Unable to evaluate column [#{column}] for record [#{id}], since [.#{part}] returns nil")
        return nil
      end
    end
    rec
  end

  # Calculate and store the matches for all results
  def calculate_all
    @ids.each { |id| calculate_record(id) }
  end

  # Calculate and store the matches for a result to the base result for all
  # checked sections
  def calculate_record(id)
    clear_calculations(id)

    # Do not calculate for the first record
    return if id == @ids[0]

    # Determine the base and result records
    base_id = case @mode
              when :compare then @ids[0]                                         # For compare, we are comparing to the first record
              when :drift then   @ids.each_cons(2) { |x, y| break(x) if y == id }  # For drift, we are comparing to the previous timestamp
              end
    base = @results[base_id]
    result = @results[id]

    # Go through the master list checking only checked items
    count = total = count_exists = total_exists = 0
    @master_list.each_slice(3) do |section, sub_sections, columns|
      section_name = section[:name]
      next unless @include[section_name][:checked] && result.key?(section_name)

      sub_count, sub_total, sub_count_exists, sub_total_exists = calculate_section(base, result, section, sub_sections, columns)

      count += sub_count
      total += sub_total
      count_exists += sub_count_exists
      total_exists += sub_total_exists

      set_match_value(:_match_, result[section_name], sub_count, sub_total)
      set_match_value(:_match_exists_, result[section_name], sub_count_exists, sub_total_exists)
    end

    set_match_value(:_match_, result, count, total)
    set_match_value(:_match_exists_, result, count_exists, total_exists)
  end

  # Calculate and store the matches for a result to the base result for a
  # particular section
  def calculate_section(base, result, section, sub_sections, columns)
    section = section[:name]
    count = total = count_exists = total_exists = 0

    if sub_sections.nil?
      # Determine the percentage of matching columns
      total = columns.length
      columns.each do |c|
        c = c[:name]
        match = base[section][c][:_value_] == result[section][c][:_value_]
        result[section][c][:_match_] = match
        count += 1 if match
      end
    else
      # Determine the percentage of results that exist in the base,
      #   and for each one determine the percentage of matching columns
      sub_total = columns.length
      total = sub_sections.length * sub_total
      total_exists = sub_sections.length
      sub_sections.each do |sub_section|
        result_has_key = result[section].key?(sub_section)
        base_has_key = base[section].key?(sub_section)

        if !result_has_key && !base_has_key
          count += sub_total
          count_exists += 1
        elsif result_has_key && base_has_key
          result[section][sub_section][:_match_exists_] = true
          count_exists += 1

          sub_count = 0
          columns.each do |c|
            c = c[:name]
            match = base[section][sub_section][c][:_value_] == result[section][sub_section][c][:_value_]
            result[section][sub_section][c][:_match_] = match
            sub_count += 1 if match
          end
          set_match_value(:_match_, result[section][sub_section], sub_count, sub_total)

          count += sub_count
        elsif result_has_key && !base_has_key
          result[section][sub_section][:_match_exists_] = false
        end
      end
    end

    return count, total, count_exists, total_exists
  end

  # Set the match value for this result
  def set_match_value(type, result, count, total)
    result[type] = (total == 0 ? 100 : count * 100 / total)
  end

  # Clear all match calculations on all results
  def clear_all_calculations
    @ids.each { |id| clear_calculations(id) }
  end

  # Recursively clear all match calculations for this result or id
  def clear_calculations(result)
    result = @results[result] unless result.kind_of?(Hash)
    result.delete(:_match_)
    result.delete(:_match_exists_)
    result.each_value { |v| clear_calculations(v) if v.kind_of?(Hash) }
  end

  # Retrieve all records from the source for the set of ids (mode agnostic)
  def get_records
    send("get_#{@mode}_records")
  end

  # Retrieve the record from the source (mode agnostic)
  def get_record(id)
    send("get_#{@mode}_record", id)
  end

  # Find the record for the specified id
  def find_record(id)
    @records[@ids.index(id)]
  end

  ### Compare specific methods

  # Retrieve all records from the source for the set of ids (compare mode)
  def get_compare_records
    return unless @mode == :compare
    recs = @model.where(:id => @ids)
    error_recs = []

    # Sort the recs to match the order of the ids, since they could be
    #   returned in a different order from ActiveRecord
    @records = @ids.collect do |id|
      new_rec = recs.find { |r| r.id == id }
      error_recs << id if new_rec.nil?
      new_rec
    end

    _log.error("No record was found for compare object #{@model}, ids: [#{error_recs.join(", ")}]") unless error_recs.blank?
  end

  # Retrieve the record from the source (compare mode)
  def get_compare_record(id)
    return unless @mode == :compare
    new_rec = @model.find_by(:id => id)
    _log.error("No record was found for compare object #{@model}, id: [#{id}]") if new_rec.nil?
    new_rec
  end

  ### Drift specific methods

  # Retrieve all records from the source for the set of ids (drift mode)
  def get_drift_records
    return unless @mode == :drift
    @records = drift_model_record.drift_states.where(:timestamp => @ids).collect(&:data_obj)
  end

  # Retrieve the record from the source (drift mode)
  def get_drift_record(ts)
    return unless @mode == :drift
    new_rec = drift_model_record.drift_states.find_by(:timestamp => ts).data_obj
    _log.error("No data was found for drift object #{@model} [#{@model_record_id}] at [#{ts}]") if new_rec.nil?
    new_rec
  end

  def drift_model_record
    return unless @mode == :drift
    @model_record ||= @model.find_by(:id => @model_record_id)
  end

  ### Special marshaling methods
  # The marshaling methods are needed to remove the potentially huge amount of
  #   data stored in the records, since MiqCompare is stored in a UI session.

  public

  IVS_TO_REMOVE_ON_DUMP = [:@records, :@model_record]

  def marshal_dump
    ivs = instance_variables.reject { |iv| iv.in?(IVS_TO_REMOVE_ON_DUMP) }
    ivs.each_with_object({}) { |iv, h| h[iv] = instance_variable_get(iv) }
  end

  def marshal_load(data)
    data.each { |iv, value| instance_variable_set(iv, value) }
    get_records
  end
end
