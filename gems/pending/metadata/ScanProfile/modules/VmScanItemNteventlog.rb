module VmScanItemNteventlog
  def to_xml
    xml = @xml_class.newNode('scan_item')
    xml.add_attributes('guid' => @params['guid'], 'name' => @params['name'], 'item_type' => @params['item_type'])
    d = scan_definition
    xml.root << d[:data] if d[:data]
    xml
  end

  def parse_data(vm, data, &_blk)
    if data.nil?
      d = scan_definition
      if d[:data].nil?
        if vm.rootTrees[0].guestOS == "Windows"
          begin
            st = Time.now
            $log.info "Scanning [Profile-EventLogs] information."
            yield({:msg => 'Scanning Profile-EventLogs'}) if block_given?
            ntevent = Win32EventLog.new(vm.rootTrees[0])
            ntevent.readAllLogs(d['content'])
          rescue MiqException::NtEventLogFormat
            $log.warn $!.to_s
          rescue => err
            $log.error "Win32EventLog: #{err}"
            $log.error err.backtrace.join("\n")
          ensure
            d[:data] = ntevent.xmlDoc
            $log.info "Scanning [Profile-EventLogs] information ran for [#{Time.now - st}] seconds."
          end
        end
      end
    end
  end
end
