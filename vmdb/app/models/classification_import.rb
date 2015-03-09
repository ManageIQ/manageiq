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
