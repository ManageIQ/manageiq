module VmScanItemNteventlog
  def to_xml()
    xml = @xml_class.newNode('scan_item')
    xml.add_attributes('guid'=>@params['guid'], 'name'=>@params['name'], 'item_type'=>@params['item_type'])
    d = self.scan_definition
    xml.root << d[:data] if d[:data]
    return xml
  end

  def parse_data(vm, data, &blk)
    if data.nil?
      d = self.scan_definition
      if d[:data].nil?
        if vm.vmRootTrees[0].guestOS == "Windows"
          begin
            st = Time.now
            $log.info "Scanning [Profile-EventLogs] information."
            yield({:msg=>'Scanning Profile-EventLogs'}) if block_given?
            ntevent = Win32EventLog.new(vm.vmRootTrees[0])
            ntevent.readAllLogs(d['content'])
          rescue MiqException::NtEventLogFormat
            $log.warn "#{$!}"
          rescue => err
            $log.error "Win32EventLog: #{err}"
            $log.error err.backtrace.join("\n")
          ensure
            d[:data] = ntevent.xmlDoc
            $log.info "Scanning [Profile-EventLogs] information ran for [#{Time.now-st}] seconds."
          end
        end
      end
    end
  end
end
