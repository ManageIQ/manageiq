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
