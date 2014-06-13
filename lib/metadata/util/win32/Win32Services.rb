$:.push("#{File.dirname(__FILE__)}/../../../util/")
$:.push("#{File.dirname(__FILE__)}/../../../util/xml/")

#require 'fleece_hives'
require 'miq-xml'
require 'miq-logger'
require 'xml_utils'
require 'xml/xml_hash'

module MiqWin32
  class Services
		attr_reader :services
	
		SERVICE_MAPPING = [
			'Type', :svc_type,
			'Start', :start,
			'ImagePath', :image_path,
			'DisplayName', :display_name,
			'ObjectName', :object_name,
			'Description', :description,
      'Type', :type,
			'DependOnService', :depend_on_service,
			'DependOnGroup', :depend_on_group,
		]

    SERVICE_VALUE_MAP = []
    (0...SERVICE_MAPPING.length).step(2) {|i| SERVICE_VALUE_MAP << SERVICE_MAPPING[i]}

		def initialize(c, fs)
			@services = []

      regHnd = RemoteRegistry.new(fs, true)
      reg_doc = regHnd.loadHive("system", [{:key=>'CurrentControlSet/Services',:depth=>0,:value=>SERVICE_VALUE_MAP}])
      regHnd.close
     
			reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services", reg_doc.root)
			if reg_node
        reg_node.each_element do |e|
          next if e.name != :key

  				# Remove child elements's that have children.  This data is not being processed on the server
    			# and adds a lot of extract size to the xml and time for tagging.
      		e.each_element {|e1| e1.remove! if e1.name == :key }
        end

				reg_node.each_element_with_attribute(:keyname) do |e|
					attrs = XmlFind.decode(e, SERVICE_MAPPING)
					attrs[:name] = e.attributes[:keyname]
          attrs[:typename] = service_type_to_string(attrs.delete(:type))
					attrs[:depend_on_service] = attrs[:depend_on_service].split(' ').collect { |d| {:name => d} } if attrs[:depend_on_service]
					attrs[:depend_on_group] = attrs[:depend_on_group].split(' ').collect { |d| {:name => d} } if attrs[:depend_on_group]

					@services << attrs
				end
			end

      # Force memory cleanup
      reg_doc = nil; GC.start
		end

    def service_type_to_string(type)
      type = type.nil? ? 1 : type.to_i
      if (type & 0x00000001) > 0
        "kernel"
      elsif (type & 0x00000002) > 0
        "filesystem"
      elsif ((type & 0x00000010) > 0) || ((type & 0x00000020) > 0)
        "win32_service"
      else
        "misc"
      end
    end

		def to_xml(doc = nil)
			doc = MiqXml.createDoc(nil) if !doc

			@services.each do |s|
				depends_service = s.delete(:depend_on_service)
				depends_group = s.delete(:depend_on_group)
				
				node = doc.add_element("service", XmlHelpers.stringify_keys(s))
				
				depends_service.each { |d| node.add_element("depend_on_service", XmlHelpers.stringify_keys(d)) } if depends_service
				depends_group.each { |d| node.add_element("depend_on_group", XmlHelpers.stringify_keys(d)) } if depends_group
      end

			doc
    end
  end
end
