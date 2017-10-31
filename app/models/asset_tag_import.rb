class AssetTagImport
  include Vmdb::Logging

  attr_accessor :errors
  attr_accessor :stats

  # The required fields list is not limited anymore, so pass nil.
  REQUIRED_COLS = {VmOrTemplate => nil, Host => nil}
  MATCH_KEYS = {
    VmOrTemplate => ["name", "hardware.networks.hostname", "guid"],
    Host         => ["name", "hostname"]
  }

  def initialize(opts = {})
    opts.each do |k, v|
      var = "@#{k}"
      instance_variable_set(var, v) unless v.nil?
    end

    @errors = ActiveModel::Errors.new(self)
  end

  def self.upload(klass, fd)
    klass = Object.const_get(klass.to_s)
    raise _("%{name} not supported for upload!") % {:name => klass} unless REQUIRED_COLS.key?(klass)
    raise _("%{name} not supported for upload!") % {:name => klass} unless MATCH_KEYS.key?(klass)
    data, keys, tags = MiqBulkImport.upload(fd, REQUIRED_COLS[klass], MATCH_KEYS[klass].dup)

    import = new(:data => data, :keys => keys, :tags => tags, :klass => klass)
    import.verify
    import
  end

  def verify
    @errors.clear
    @verified_data = {}
    good = bad = 0

    @data.each do |line|
      keys = []
      @keys.each do |k|
        t = []
        t[0] = k
        t[1] = line[k]
        keys.push(t)
      end
      objs = MiqBulkImport.find_entry_by_keys(@klass, keys)
      if objs.empty?
        bad += 1
        _log.warn("#{@keys[0].titleize} #{line[@keys[0]]}: Unable to find a #{@klass.name}")
        err = "#{@klass.name.downcase}notfound".to_sym
        @errors.add(err, "#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find a #{@klass.name}")
        next
      end
      if objs.length > 1
        bad += 1
        err = "serveral#{@klass.name.downcase}sfound4keys".to_sym
        _log.warn("#{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a #{@klass.name}, an entry will be skipped")
        @errors.add(err, "#{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a #{@klass.name}, an entry will be skipped")
      else
        @verified_data[objs[0].id] ||= []
        tags = {}
        @tags.each do |tag|
          tags[tag] = line[tag]
        end
        @verified_data[objs[0].id].push(tags)
        good += 1
      end
    end

    @verified_data.each do |id, data|
      if data.length > 1
        obj = @klass.find_by(:id => id)
        while data.length > 1
          data.shift
          _log.warn("#{@klass.name} #{obj.name}, Multiple lines for the same object, the last line is applied")
          @errors.add(:singlevaluedassettag, "#{@klass.name}: #{obj.name}, Multiple lines for the same object, the last line is applied")
        end
      end
    end

    @stats = {:good => good, :bad => bad}
    _log.info("Number of valid entries #{@stats[:good]}, number of invalid entries #{@stats[:bad]}")
    @stats
  end

  def apply
    @verified_data.each do |id, data|
      obj = @klass.find_by(:id => id)
      if obj
        attrs = obj.miq_custom_attributes
        new_attrs = []
        data[0].each do |key, value|
          # Add custom attribute here.
          attr = attrs.detect { |ca| ca.name == key }
          if attr.nil?
            if value.blank?
              _log.info("#{@klass.name}: #{obj.name}, Skipping tag <#{key}> due to blank value")
            else
              _log.info("#{@klass.name}: #{obj.name}, Adding tag <#{key}>, value <#{value}>")
              new_attrs << {:name => key, :value => value, :source => 'EVM'}
            end
          else
            if value.blank?
              _log.info("#{@klass.name}: #{obj.name}, Deleting tag <#{key}> due to blank value")
              attr.delete
            else
              _log.info("#{@klass.name}: #{obj.name}, Updating tag <#{key}>, value <#{value}>")
              attr.update_attribute(:value, value)
            end
          end
        end
        obj.custom_attributes.create(new_attrs)
      end
    end
  end
end
