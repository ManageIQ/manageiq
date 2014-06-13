$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-xml'
require 'runcmd'

module XmlConfig
	def convert(filename)
		@convertText = ""
		#$log.debug "Processing Windows Configuration file [#{filename}]"

    xml_data = nil
    unless File.file?(filename)
      if Platform::IMPL == :linux
        begin
          # First check to see if the command is available
          MiqUtil.runcmd("virsh list")
          begin
            xml_data = MiqUtil.runcmd("virsh dumpxml #{File.basename(filename, ".*")}")
          rescue => err
            $log.error "#{err}\n#{err.backtrace.join("\n")}"
          end
        rescue
        end
      end
      raise "Cannot open config file: [#{filename}]" if xml_data.blank?
    end

    if xml_data.nil?
      fileSize = File.size(filename)
      raise "Specified XML file [#{filename}] is not a valid VM configuration file." if fileSize > 104857
      xml = MiqXml.loadFile(filename)
      if xml.encoding == "UTF-16" && xml.root.nil? && Object.const_defined?('Nokogiri')
        xml_data = File.open(filename) {|f| Nokogiri::XML(f)}.to_xml(:encoding => "UTF-8")
        xml = MiqXml.load(xml_data)
      end
    else
      xml = MiqXml.load(xml_data)
    end
    xml_type = nil
    xml_type = :xen unless xml.find_first("//vm/thinsyVmm").nil?
    xml_type = :ms_hyperv  unless xml.find_first("//configuration/properties/type_id").nil?
    xml_type = :kvm if xml.root.name == 'domain' && ['kvm', 'qemu'].include?(xml.root.attributes['type'])

    raise "Specified XML file [#{filename}] is not a valid VM configuration file." if xml_type.nil?

    case xml_type
    when :kvm
      require "kvmConfig"
      extend  KvmConfig
    when :ms_hyperv
      require "xmlMsHyperVConfig"
      extend  XmlMsHyperVConfig
    end

    xml_to_config(xml)

    return @convertText
	end

  def xml_to_config(xml)
    xml.each_recursive { |e| self.send(e.name, e) if self.respond_to?(e.name) && !['id', 'type'].include?(e.name.downcase)}
  end

	def vm(element)
		add_item("displayName", element.attributes['name'])
		add_item("memsize", element.attributes['minmem'])
	end
	
	def vmmversion(element)
		add_item("config.version", element.text)
	end	

	def vdisk(element)
		index = element.attributes['index'].to_i
		add_item("scsi0:#{index}.fileName", element.elements[1].text)
	end

	def add_item(var, value)
		@convertText += "#{var} = \"#{value}\"\n"
	end

  def vendor
    return "xen"
  end
end
