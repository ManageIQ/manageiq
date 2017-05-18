require 'xml/xml_utils'

class XmlData < ActiveRecord::Base
  def self.emsinventory(emsId, data)
    doc = REXML::Document.new(data)
    _log.info "request received from ems id: #{emsId}"
    Storage.save_emsinventory(emsId, Xml2Array.getNodeDetails(doc, "Datastores"))
    Host.save_ems_inventory(emsId, Xml2Array.getNodeDetails(doc, "HostSystems"))
  end

  def self.emsevents(emsId, data)
    _log.info "request received from ems id: #{emsId}"
    handler = EventXmlHandler.new
    Document.parse_stream(data, handler)
    $log.debug handler.result.inspect

    handler.result.each { |event| eval "VmwareEmsEvent.#{event[:type]}(event)" }
  end
end

# Generic event processor class
require 'rexml/document'
require 'rexml/streamlistener'

class EventXmlHandler
  include REXML
  include StreamListener

  def initialize
    @tags = []
    @result = []
    @event = {}
    @host = {}
    @vm = {}
  end

  attr_reader :result

  def tag_start(name, _attrs)
    @tags.push name
  end

  def tag_end(name)
    @tags.pop

    case name
    when "emsEvents"
    when "event"
      @result.push(@event)
      @event = {}
    when "host", "srcHost", "destHost"
      @event[name.to_sym] = @host
      @host = {}
    when "vm", "srcVm", "destVm"
      @event[name.to_sym] = @vm
      @vm = {}
    end
  end

  def text(value)
    return if value.strip.blank?
    obj, name = @tags.last(2)
    case obj
    when "event"
      @event[name.to_sym] = value
    when "host", "srcHost", "destHost"
      @host[name.to_sym] = value
    when "vm", "srcVm", "destVm"
      @vm[name.to_sym] = value
    end
  end
end
