class ClassificationImport
  include Vmdb::Logging
  attr_accessor :errors
  attr_accessor :stats

  REQUIRED_COLS = ["category", "entry"]
  MATCH_KEYS = ["name", "hardware.networks.hostname", "guid"]

  def initialize(data)
    @data = data[0]
    @keys = data[1]
    @errors = ActiveModel::Errors.new(self)
  end

  def self.upload(fd)
    import = new(MiqBulkImport.upload(fd, REQUIRED_COLS.dup, MATCH_KEYS.dup))
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
      vms = MiqBulkImport.find_entry_by_keys(VmOrTemplate, keys)
      if vms.empty?
        bad += 1
        _log.warn("#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find VM")
        @errors.add(:vmnotfound, "#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find VM")
        next
      end
      if vms.length > 1
        bad += 1
        _log.warn("#{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a vm, an entry will be skipped")
        @errors.add(:severalvmsfound4keys, "#{@keys[0].titleize}: #{line[@keys[0]]}: Could not resolve a vm, an entry will be skipped")
      else
        cat = Classification.find_by(:description => line["category"])
        if cat.nil?
          bad += 1
          _log.warn("#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find category #{line["category"]}")
          @errors.add(:categorynotfound, "#{@keys[0].titleize}: #{line[@keys[0]]}: Unable to find category #{line["category"]}")
          next
        end

        @verified_data[vms[0].id] ||= {}
        @verified_data[vms[0].id][line["category"]] ||= []
        entry = nil
        cat.entries.each do |e|
          if e.description == line["entry"]
            @verified_data[vms[0].id][line["category"]].push(line["entry"])
            entry = e
            break
          end
        end
        if entry.nil?
          bad += 1
          _log.warn("#{@keys[0].titleize}: #{line[@keys[0]]}, category: #{line["category"]}: Unable to find entry #{line["entry"]})")
          @errors.add(:entrynotfound, "#{@keys[0].titleize}: #{line[@keys[0]]}, category: #{line["category"]}: Unable to find entry #{line["entry"]}")
          next
        end
        good += 1
      end
    end

    @verified_data.each do |id, data|
      data.each do |category, entries|
        cat = Classification.find_by(:description => category)
        if cat.single_value && entries.length > 1
          vm = VmOrTemplate.find_by(:id => id)
          while entries.length > 1
            e = entries.shift
            _log.warn("Vm: #{vm.name}, Location: #{vm.location}, Category: #{category}: Multiple values given for single-valued category, value #{e} will be ignored")
            @errors.add(:singlevaluedcategory, "Vm #{vm.name}, Location: #{vm.location}, Category: #{category}: Multiple values given for single-valued category, value #{e} will be ignored")
          end
        end
      end
    end
    @stats = {:good => good, :bad => bad}
    _log.info("Number of valid entries: #{@stats[:good]}, number of invalid entries: #{@stats[:bad]}")
    @stats
  end

  def apply
    @verified_data.each do |id, data|
      vm = VmOrTemplate.find_by(:id => id)
      if vm
        data.each do |category, entries|
          cat = Classification.find_by(:description => category)
          next unless cat
          entries.each do |ent|
            cat.entries.each do |e|
              if e.description == ent
                _log.info("Vm: #{vm.name}, Location: #{vm.location}, Category: #{cat.description}: Applying entry #{ent}")
                e.assign_entry_to(vm)
                break
              end
            end
          end
        end
      end
    end
  end
end
