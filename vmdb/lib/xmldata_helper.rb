$:.push("#{File.dirname(__FILE__)}/../../../lib/util/xml")

require 'xml_utils'

class XmlData < ActiveRecord::Base
  def self.emsinventory(emsId, data)
    doc = REXML::Document.new(data)
    $log.info "MIQ(XmlData.emsinventory): request received from ems id: #{emsId}"
    Storage.save_emsinventory(emsId, Xml2Array.getNodeDetails(doc, "Datastores"))
    Host.save_ems_inventory(emsId, Xml2Array.getNodeDetails(doc, "HostSystems"))
  end

  def self.emsevents(emsId, data)
    $log.info "MIQ(XmlData.emsevents): request received from ems id: #{emsId}"
    handler = EventXmlHandler.new
    Document.parse_stream(data, handler)
    $log.debug "#{handler.result.inspect}"

    handler.result.each {|event| eval "VmwareEmsEvent.#{event[:type]}(event)" }
  end
end

# Generic event processor class
require 'rexml/document'
require 'rexml/streamlistener'

class EventXmlHandler
  include REXML
  include StreamListener

  def initialize
    @tags = Array.new
    @result = Array.new
    @event = Hash.new
    @host = Hash.new
    @vm = Hash.new
  end

  def result
    return @result
  end

  def tag_start(name, attrs)
    @tags.push name
  end

  def tag_end(name)
    @tags.pop

    case name
    when "emsEvents"
    when "event"
      @result.push(@event)
      @event = Hash.new
    when "host", "srcHost", "destHost"
      @event[name.to_sym] = @host
      @host = Hash.new
    when "vm", "srcVm", "destVm"
      @event[name.to_sym] = @vm
      @vm = Hash.new
    end
  end

  def text value
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
