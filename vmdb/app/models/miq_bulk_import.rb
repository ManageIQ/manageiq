require 'csv'

module MiqBulkImport
  def self.upload(fd, tags, keys)
    log_prefix = 'MIQ(MiqBulkImport.upload)'
    $log.info "#{log_prefix} Uploading CSV file"
    data = fd.read
    data.gsub!(/\r/, "\n")
    begin
      reader = CSV.parse(data)
    rescue CSV::IllegalFormatError
      $log.error "#{log_prefix} CSV file is invalid"
      raise "CSV file is invalid"
    end
    header = reader.shift

    tags = (header - keys).collect(&:dup) if tags.nil?

    verified_tags = tags.collect {|t| t if header.include?(t)}.compact
    unless verified_tags.empty?
      $log.info "#{log_prefix} The following columns are verified in the csv file: #{verified_tags.join(" and ")}"
    else
      raise "No valid columns were found in the csv file. One of the following fields is required: (#{tags.join(" ")})."
    end

    matched_keys = []
    keys.each {|k|
      if header.include?(k)
        matched_keys.push(k)
        tags = tags.unshift(k)
      end
    }

    if matched_keys.empty?
      $log.error "#{log_prefix} The following required columns used for matching are missing: #{keys.join(" or ")}"
      raise "The following required columns used for matching are missing: #{keys.join(" or ")}"
    end

    result = []
    reader.each {|row|
      next if row.first.nil?
      line = {}
      header.each_index{|i|
        next unless tags.include?(header[i])
        line[header[i]] = row[i].strip if row[i]
      }
      result.push(line)
    }
    return [result, matched_keys, verified_tags]
  end

  def self.find_entry_by_keys(klass, keys)
    keys2array = keys
    primary_key, primary_key_value = keys2array.shift
    result = klass.where("LOWER(#{primary_key}) LIKE '#{primary_key_value.downcase}'")
    return result if result.size <= 1

    filtered_result = []
    loop do
      break if keys2array.empty?

      sub_key, sub_key_value = keys2array.shift
      next if sub_key_value.blank?

      filtered_result = result.collect {|rec|
        rec if self.get_sub_key_values(rec, sub_key).include?(sub_key_value.downcase)
      }.compact

      return filtered_result if filtered_result.length == 1
    end

    return result # return original result if we were unable to resolve dups
  end

  def self.get_sub_key_values(rec, sub_key)
    if !sub_key.include?(".")
      return [] unless rec.respond_to?(sub_key)
      return rec.send(sub_key).downcase
    end

    # hardware.networks.hostname
    parts = sub_key.split(".")
    attr = parts.pop

    current = rec
    parts.each {|p|
      return [] if !current.is_a?(ActiveRecord::Base) && p != parts.last # we're only supporting multi-value for the last relationship
      return [] unless current.respond_to?(p)

      current = current.send(p)
    }
    current = current.is_a?(ActiveRecord::Base) ? [current] : current

    results = current.collect {|c|
      return [] unless c.respond_to?(attr)
      c.send(attr)
    }.compact

    return results
  end
end

class AssetTagImport
  attr_accessor :errors
  attr_accessor :stats

  # The required fields list is not limited anymore, so pass nil.
  REQUIRED_COLS = {VmOrTemplate => nil, Host => nil}
  MATCH_KEYS = {
    VmOrTemplate => ["name","hardware.networks.hostname","guid"],
    Host => ["name", "hostname"]
  }

  def initialize(opts = {})
    opts.each do |k, v|
      var = "@#{k}"
      self.instance_variable_set(var, v) unless v.nil?
    end

    @errors = ActiveModel::Errors.new(self)
  end

  def self.upload(klass, fd)
    klass = Object.const_get(klass.to_s)
    raise "#{klass} not supported for upload!" unless REQUIRED_COLS.has_key?(klass)
    raise "#{klass} not supported for upload!" unless MATCH_KEYS.has_key?(klass)
    data, keys, tags = MiqBulkImport.upload(fd, REQUIRED_COLS[klass], MATCH_KEYS[klass].dup)

    import = self.new(:data => data, :keys => keys, :tags => tags, :klass => klass)
    import.verify
    return import
  end

  def verify
    log_prefix = 'MIQ(AssetTagImport.verify)'
    @errors.clear
    @verified_data = {}
    good = bad = 0

    @data.each {|line|
      keys = []
      @keys.each{|k|
        t = []
        t[0] = k
        t[1] = line[k]
        keys.push(t)
      }
      objs = MiqBulkImport.find_entry_by_keys(@klass, keys)
      if objs.empty?
        bad += 1
        $log.warn "#{log_prefix} #{@keys[0].titleize} #{line[@keys[0]]}: Unable to find a #{@klass.name}"
        err = "#{@klass.name.downcase}notfound".to_sym
        @errors.add(err, "#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find a #{@klass.name}")
        next
      end
      if objs.length > 1
        bad += 1
        err = "serveral#{@klass.name.downcase}sfound4keys".to_sym
        $log.warn "#{log_prefix} #{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a #{@klass.name}, an entry will be skipped"
        @errors.add(err, "#{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a #{@klass.name}, an entry will be skipped")
      else
        @verified_data[objs[0].id] ||= []
        tags = {}
        @tags.each{|tag|
          tags[tag] = line[tag]
        }
        @verified_data[objs[0].id].push(tags)
        good += 1
      end
    }

    @verified_data.each{|id, data|
      if data.length > 1
        obj = @klass.find_by_id(id)
        while data.length > 1
          data.shift
          $log.warn "#{log_prefix} #{@klass.name} #{obj.name}, Multiple lines for the same object, the last line is applied"
          @errors.add(:singlevaluedassettag, "#{@klass.name}: #{obj.name}, Multiple lines for the same object, the last line is applied")
        end
      end
    }

    @stats = {:good => good, :bad => bad}
    $log.info "#{log_prefix} Number of valid entries #{@stats[:good]}, number of invalid entries #{@stats[:bad]}"
    return @stats
  end

  def apply
    log_prefix = 'MIQ(AssetTagImport.apply)'
    @verified_data.each do |id, data|
      obj = @klass.find_by_id(id)
      if obj
        attrs = obj.miq_custom_attributes
        new_attrs = []
        data[0].each do |key, value|
          # Add custom attribute here.
          attr = attrs.detect {|ca| ca.name == key}
          if attr.nil?
            if value.blank?
              $log.info "#{log_prefix} #{@klass.name}: #{obj.name}, Skipping tag <#{key}> due to blank value"
            else
              $log.info "#{log_prefix} #{@klass.name}: #{obj.name}, Adding tag <#{key}>, value <#{value}>"
              new_attrs << {:name => key, :value => value, :source => 'EVM'}
            end
          else
            if value.blank?
              $log.info "#{log_prefix} #{@klass.name}: #{obj.name}, Deleting tag <#{key}> due to blank value"
              attr.delete
            else
              $log.info "#{log_prefix} #{@klass.name}: #{obj.name}, Updating tag <#{key}>, value <#{value}>"
              attr.update_attribute(:value, value)
            end
          end
        end
        obj.custom_attributes.create(new_attrs)
      end
    end
  end
end

class ClassificationImport
  attr_accessor :errors
  attr_accessor :stats

  REQUIRED_COLS = ["category", "entry"]
  MATCH_KEYS = ["name","hardware.networks.hostname","guid"]

  def initialize(data)
    @data = data[0]
    @keys = data[1]
    @errors = ActiveModel::Errors.new(self)
  end

  def self.upload(fd)
    import = self.new(MiqBulkImport.upload(fd, REQUIRED_COLS.dup, MATCH_KEYS.dup))
    import.verify
    return import
  end

  def verify
    log_prefix = 'MIQ(ClassificationImport.verify)'
    @errors.clear
    @verified_data = {}
    good = bad = 0
    @data.each {|line|
      keys = []
      @keys.each{|k|
        t = []
        t[0] = k
        t[1] = line[k]
        keys.push(t)
      }
      vms = MiqBulkImport.find_entry_by_keys(VmOrTemplate, keys)
      if vms.empty?
        bad += 1
        $log.warn "#{log_prefix} #{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find VM"
        @errors.add(:vmnotfound, "#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find VM")
        next
      end
      if vms.length > 1
        bad += 1
        $log.warn "#{log_prefix} #{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a vm, an entry will be skipped"
        @errors.add(:severalvmsfound4keys, "#{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a vm, an entry will be skipped")
      else
        cat = Classification.find_by_description(line["category"])
        if cat.nil?
          bad += 1
          $log.warn "#{log_prefix} #{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find category #{line["category"]}"
          @errors.add(:categorynotfound, "#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find category #{line["category"]}")
          next
        end

        @verified_data[vms[0].id] ||= {}
        @verified_data[vms[0].id][line["category"]] ||= []
        entry = nil
        cat.entries.each {|e|
          if e.description == line["entry"]
            @verified_data[vms[0].id][line["category"]].push(line["entry"])
            entry = e
            break
          end
        }
        if entry.nil?
          bad += 1
          $log.warn "#{log_prefix} #{@keys[0].titleize}: #{line[@keys[0]]}, category: #{line["category"]}: Unable to find entry #{line["entry"]})"
          @errors.add(:entrynotfound, "#{@keys[0].titleize}: #{line[@keys[0]]}, category: #{line["category"]}: Unable to find entry #{line["entry"]}")
          next
        end
        good += 1
      end
    }

    @verified_data.each{|id, data|
      data.each{|category, entries|
        cat = Classification.find_by_description(category)
        if cat.single_value && entries.length > 1
          vm = VmOrTemplate.find_by_id(id)
          while entries.length > 1
            e = entries.shift
            $log.warn "#{log_prefix} Vm: #{vm.name}, Location: #{vm.location}, Category: #{category}: Multiple values given for single-valued category, value #{e} will be ignored"
            @errors.add(:singlevaluedcategory, "Vm #{vm.name}, Location: #{vm.location}, Category: #{category}: Multiple values given for single-valued category, value #{e} will be ignored")
          end
        end
      }
    }
    @stats = {:good => good, :bad => bad}
    $log.info "#{log_prefix} Number of valid entries: #{@stats[:good]}, number of invalid entries: #{@stats[:bad]}"
    return @stats
  end

  def apply
    @verified_data.each {|id, data|
      vm = VmOrTemplate.find_by_id(id)
      if vm
        data.each{|category, entries|
          cat = Classification.find_by_description(category)
          next unless cat
          entries.each{|ent|
            cat.entries.each {|e|
              if e.description == ent
                $log.info "MIQ(ClassificationImport-apply) Vm: #{vm.name}, Location: #{vm.location}, Category: #{cat.description}: Applying entry #{ent}"
                e.assign_entry_to(vm)
                break
              end
            }
          }
        }
      end
    }
  end
end
