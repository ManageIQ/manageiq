$:.push("#{File.dirname(__FILE__)}/../../../util/")
$:.push("#{File.dirname(__FILE__)}/../../../util/xml/")

require 'xml_utils'
#require 'fleece_hives'
require 'miq-xml'
require 'miq-logger'

module MiqWin32
  class System
		attr_reader :os, :account_policy, :networks

		OS_MAPPING = [
			'ProductName',        :product_name,
			'CurrentVersion',     :version,
			'CurrentBuildNumber', :build,
			'SystemRoot',         :system_root,
			'CSDVersion',         :service_pack,
			'ProductId',          :productid,
			'DigitalProductId',   :product_key,
			'Vendor',             :distribution,
      'EditionID',          :edition_id,
		]

		COMPUTER_NAME_MAPPING = [
			'ComputerName',       :machine_name,
		]

		PRODUCT_OPTIONS_MAPPING = [
			'ProductType',        :product_type,
      'ProductSuite',       :product_suite,
		]

		ENVIRONMENT_MAPPING = [
			'PROCESSOR_ARCHITECTURE', :architecture
		]

		TCPIP_MAPPING = [
			"Hostname", :hostname,
		]

		NETWORK_CARDS_MAPPING = [
			"ServiceName", :guid,
			"Description", :description,
		]

		DHCP_MAPPING = [
			"EnableDHCP", :dhcp_enabled,
			"DhcpIPAddress", :ipaddress,
			"DhcpSubnetMask", :subnet_mask,
			"LeaseObtainedTime", :lease_obtained,
			"LeaseTerminatesTime", :lease_expires,
			"DhcpDefaultGateway", :default_gateway,
			"DhcpServer", :dhcp_server,
			"DhcpNameServer", :dns_server,
      "DhcpDomain", :domain,
		]

		STATIC_MAPPING = [
			"EnableDHCP", :dhcp_enabled,
			"IPAddress", :ipaddress,
			"SubnetMask", :subnet_mask,
			"DefaultGateway", :default_gateway,
			"NameServer", :dns_server,
      "Domain", :domain,
		]

    # Software registry value filters
    OS_MAPPING_VALUES, NETWORK_CARDS_VALUES = [], []
    (0...OS_MAPPING.length).step(2) {|i| OS_MAPPING_VALUES << OS_MAPPING[i]}
    (0...NETWORK_CARDS_MAPPING.length).step(2) {|i| NETWORK_CARDS_VALUES << NETWORK_CARDS_MAPPING[i]}

    # System registry value filters
    PRODUCT_OPTIONS_VALUES, ENVIRONMENT_VALUES, COMPUTER_NAME_VALUES, TCPIP_VALUES = [], [], [], []
    (0...PRODUCT_OPTIONS_MAPPING.length).step(2) {|i| PRODUCT_OPTIONS_VALUES << PRODUCT_OPTIONS_MAPPING[i]}
    (0...ENVIRONMENT_MAPPING.length).step(2) {|i| ENVIRONMENT_VALUES << ENVIRONMENT_MAPPING[i]}
    (0...COMPUTER_NAME_MAPPING.length).step(2) {|i| COMPUTER_NAME_VALUES << COMPUTER_NAME_MAPPING[i]}
    (0...TCPIP_MAPPING.length).step(2) {|i| TCPIP_VALUES << TCPIP_MAPPING[i]}
    (0...DHCP_MAPPING.length).step(2) {|i| TCPIP_VALUES << DHCP_MAPPING[i]}
    (0...STATIC_MAPPING.length).step(2) {|i| TCPIP_VALUES << STATIC_MAPPING[i]}


		def initialize(c, fs)
			@networks = []

      regHnd = RemoteRegistry.new(fs, true)
      software_doc = regHnd.loadHive("software", [
          {:key=>"Microsoft/Windows NT/CurrentVersion",:depth=>1,:value=>OS_MAPPING_VALUES},
          {:key=>"Microsoft/Windows NT/CurrentVersion/NetworkCards",:depth=>0,:value=>NETWORK_CARDS_VALUES}
      ])

      regHnd.close()

      regHnd = RemoteRegistry.new(fs, true)
      sys_doc = regHnd.loadHive("system", [
        {:key=>'CurrentControlSet/Control/ComputerName/ComputerName', :value=> COMPUTER_NAME_VALUES},
        {:key=>'CurrentControlSet/Control/Session Manager/Environment',:value=>ENVIRONMENT_VALUES},
        {:key=>'CurrentControlSet/Control/ProductOptions',:value=>PRODUCT_OPTIONS_VALUES},
        {:key=>'CurrentControlSet/Services/Tcpip/Parameters',:value=>TCPIP_VALUES},
      ])
      regHnd.close()

			# Get the OS information
			attrs = {:type => "windows"}

			reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", software_doc.root)
			attrs.merge!(XmlFind.decode(reg_node, OS_MAPPING)) if reg_node
			
			reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\ComputerName", sys_doc.root)
			attrs.merge!(XmlFind.decode(reg_node, COMPUTER_NAME_MAPPING)) if reg_node
			
			reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\ProductOptions", sys_doc.root)
			attrs.merge!(XmlFind.decode(reg_node, PRODUCT_OPTIONS_MAPPING)) if reg_node
			
			reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment", sys_doc.root)
			attrs.merge!(XmlFind.decode(reg_node, ENVIRONMENT_MAPPING)) if reg_node
			
			attrs[:product_key] = MiqWin32::Software.DecodeProductKey(attrs[:product_key]) if attrs[:product_key]
      
			attrs[:architecture] = architecture_to_string(attrs[:architecture])

      # Parse product edition and append to product_name if needed.
      os_product_suite(attrs)

			@os = attrs

			# Get the network card information
 
			# Hold onto the parameters common to all network cards
			reg_tcpip = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters", sys_doc.root)
			if reg_tcpip
				tcpip_params = XmlFind.decode(reg_tcpip, TCPIP_MAPPING)
				tcpip_params[:domain] = XmlFind.findNamedElement_hash("Domain", reg_tcpip)
				tcpip_params[:domain] = XmlFind.findNamedElement_hash("DhcpDomain", reg_tcpip) if tcpip_params[:domain].blank?
				tcpip_params[:domain] = nil if tcpip_params[:domain].blank?

				# Find each netword card, and get it's individual parameters
				reg_networkCards = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\NetworkCards", software_doc.root)
				if reg_networkCards.kind_of?(Hash)
					reg_networkCards.each_element do |networkCard|
						attrs = XmlFind.decode(networkCard, NETWORK_CARDS_MAPPING)

						params = XmlFind.findElement("Interfaces/#{attrs[:guid]}", reg_tcpip)
						next if params.nil?

						# Add the common parameters
						attrs.merge!(tcpip_params)

						# Blank out fields that are not shared between network types
						attrs[:lease_obtained] = attrs[:lease_expires] = attrs[:dhcp_server] = nil

						# Get the rest of the parameters based on whether this network is DHCP enabled
						dhcp = XmlFind.findNamedElement_hash("EnableDHCP", params)            
            attrs.merge!(XmlFind.decode(params, dhcp.to_i == 1 ? DHCP_MAPPING : STATIC_MAPPING))

						# Remove the extra curly braces from the guid
						attrs[:guid] = attrs[:guid][1..-2] unless attrs[:guid].nil?

						# Clean the lease times and check they are in a reasonable range
            [:lease_obtained, :lease_expires].each do |t|
              attrs[t] = Time.at(attrs[t].to_i).getutc.iso8601 if attrs[t] && attrs[t].to_i >= 0 && attrs[t].to_i < 0x80000000
						end
						@networks << attrs
					end
				end
			end
			
			# Extracted data also built into a human-readable format if uncommented
			#@debug_str = ''

      # Force memory cleanup
      software_doc = nil; sys_doc = nil; GC.start;

      regHnd = RemoteRegistry.new(fs, true)
      sam_doc = regHnd.loadHive("sam", [{:key=>"SAM/Domains/Account",:depth=>1,:value=>['F']}])
      regHnd.close()

			# Extract the local account policy from the registry
			@debug_str += "Account Policy:\n" if @debug_str
			reg_node = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SAM\\SAM\\Domains\\Account", sam_doc.root)
			if reg_node
				reg_node.each_element(:value) do |e|
					acct_policy_f = process_acct_policy_f(e.text) if e.attributes[:name] == "F"
					
					unless acct_policy_f.nil?
						# Remove unused elements
						acct_policy_f.delete(:auto_increment)
						acct_policy_f.delete(:next_rid)
						acct_policy_f.delete(:pw_encrypt_pw_complex)
						acct_policy_f.delete(:syskey)
						
						@account_policy = acct_policy_f
					end					
				end
			end

			# Dump the debug string to a file if we are collecting that data
			#File.open('C:/Temp/reg_extract_full_system.txt', 'w') { |f| f.write(@debug_str) } if @debug_str
      if $log
        os_dup = @os.dup
        [:productid, :product_key].each {|k| os_dup.delete(k)}
        $log.info "VM OS information: [#{os_dup.inspect}]"
      end
		end

		def to_xml(doc = nil)
			doc = MiqXml.createDoc(nil) if !doc
			osToXml(doc)
			accountPolicyToXml(doc)
			networksToXml(doc)
			doc
    end
		
		def osToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
			doc.add_element(:os, @os) unless @os.empty?
			doc
		end
    
		def accountPolicyToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
			doc.add_element(:account_policy, @account_policy) unless @account_policy.blank?
			doc
		end
		
		def networksToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
			unless @networks.empty?
				node = doc.add_element(:networks)
				@networks.each { |n| node.add_element(:network, n) }
			end
			doc
		end

    def architecture_to_string(architecture)
      case architecture
      when "x86" then 32
			when "AMD64" then 64
			else nil
			end
    end

    # Parse product edition and append to product_name if needed.
    def os_product_suite(hash)
      eid = hash.delete(:edition_id)
      ps = hash.delete(:product_suite)
      
      # If edition_id is populated then the edition will already be part of the product_name string
      if eid.nil? && !hash[:product_name].nil?
        ps = ps.to_s.split("\n")
        if ps.length > 1 && !hash[:product_name].include?(ps.first)
          hash[:product_name] = "#{hash[:product_name].strip} #{ps.first} Edition"
        end
      end
    end
		
		# Definition derived from http://www.beginningtoseethelight.org/ntsecurity/#BB4F910C0FFA1E43
		# \HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\F
		SAM_STRUCT_ACCT_POLICY = BinaryStruct.new([
			'a16',	nil,											# UNKNOWN
			'Q',		:auto_increment,					# Auto-increment
			'Q',		:max_pw_age,							# Maximum password age (>=0 & <=999) days - minus from qword:ff + 1 = seconds x 10 million
			'Q',		:min_pw_age,							# Minimum password age (>=0 & <=999) days - minus from qword:ff + 1 = seconds x 10 million
			'a8',		nil,											# UNKNOWN
			'Q',		:lockout_duration,				# Account lockout duration (>=0 & <=99,999) minutes - minus from qword:ff + 1 = seconds x 10 million
			'Q',		:reset_lockout_counter,	  # Reset account lockout counter after (>=1 & <=99,999) minutes - minus from qword:ff + 1 = seconds x 10 million
			'a8',		nil,											# UNKNOWN
			'I',		:next_rid,								# Next created users RID
			'C',		:pw_encrypt_pw_complex,	  # High nibble
																				#   Store password using reversible encryption for all users in the domain (enabled=1/disabled=0)
																				# Low nibble
																				#   Password must meet complexity requirements (enabled=1/disabled=0)
			'a3',		nil,											# UNKNOWN
			'C',		:min_pw_len,							# Minimum password length (>=0 & <=14) characters
			'a1',		nil,											# UNKNOWN
			'C',		:pw_hist,								  # Enforce password history (>=0 & <=24) passwords remembered
			'a1',		nil,											# UNKNOWN
			'S',		:lockout_threshold,			  # Account lockout threshold (>=0 & <=999) attempts
			'a26',	nil,											# UNKNOWN
			'a48',	:syskey,									# Part of syskey
			'a8',		nil,											# UNKNOWN
    ])
		
		def process_acct_policy_f(data)
			bin = MSRegHive.regBinaryToRawBinary(data)
			f = SAM_STRUCT_ACCT_POLICY.decode(bin)
			
			@debug_str += "  auto_increment        - %s\n" % f[:auto_increment] if @debug_str
			
			@debug_str += "  max_pw_age            - %s - " % f[:max_pw_age] if @debug_str
			f[:max_pw_age] = process_acct_policy_f_date(f[:max_pw_age]) / 86400
			@debug_str += "%s days\n" % f[:max_pw_age] if @debug_str
			
			@debug_str += "  min_pw_age            - %s - " % f[:min_pw_age] if @debug_str
			f[:min_pw_age] = process_acct_policy_f_date(f[:min_pw_age]) / 86400
			@debug_str += "%s days\n" % f[:min_pw_age] if @debug_str
			
			@debug_str += "  lockout_duration      - %s - " % f[:lockout_duration] if @debug_str
			f[:lockout_duration] = process_acct_policy_f_date(f[:lockout_duration]) / 60
			@debug_str += "%s minutes\n" % f[:lockout_duration] if @debug_str
			
			@debug_str += "  reset_lockout_counter - %s - " % f[:reset_lockout_counter] if @debug_str
			f[:reset_lockout_counter] = process_acct_policy_f_date(f[:reset_lockout_counter]) / 60
			@debug_str += "%s minutes\n" % f[:reset_lockout_counter] if @debug_str
			
			@debug_str += "  next_rid              - %s\n" % f[:next_rid] if @debug_str
			
			@debug_str += "  pw_encrypt_pw_complex - 0x%02x\n" % f[:pw_encrypt_pw_complex] if @debug_str
			f[:pw_encrypt], f[:pw_complex] = process_acct_policy_f_pw_encrypt_pw_complex(f[:pw_encrypt_pw_complex])
			@debug_str += "    pw_encrypt          - %s\n" % f[:pw_encrypt] if @debug_str
			@debug_str += "    pw_complex          - %s\n" % f[:pw_complex] if @debug_str
			
			if @debug_str
				@debug_str += "  min_pw_len            - %s characters\n" % f[:min_pw_len]
				@debug_str += "  pw_hist               - %s passwords remembered\n" % f[:pw_hist]
				@debug_str += "  lockout_threshold     - %s attempts\n" % f[:lockout_threshold]
				@debug_str += "  syskey                - %s\n" % Accounts.rawBinaryToRegBinary(f[:syskey])
			end
			
			return f
    end
		
		def process_acct_policy_f_date(data)
			return 0 if data == 0 || data == 0x8000000000000000
			# minus from qword:ff + 1 = seconds x 10 million
			return (0x10000000000000000 - data) / 10000000
    end
		
		def process_acct_policy_f_pw_encrypt_pw_complex(data)
			pw_encrypt = data >> 4
			pw_encrypt = (pw_encrypt == 1)

			pw_complex = data & 0x0F
			pw_complex = (pw_complex == 1)
			
			return pw_encrypt, pw_complex
    end
  end
end
