$:.push("#{File.dirname(__FILE__)}/../../../util/")

#require 'fleece_hives'
require 'miq-xml'
require 'miq-logger'
require 'enumerator'

module MiqWin32
  class Accounts
		attr_reader :users, :groups
	
		def initialize(c, fs)
			@users = []
			@groups = []

			# Extracted data also built into a human-readable format if uncommented
			#@debug_str = ''
			
      regHnd = RemoteRegistry.new(fs, true)
			reg_doc = regHnd.loadHive("sam", nil)
      regHnd.close()
			
			# Collect a mapping of user SIDs to user names for user-group relationships
			users_by_sids = {}
			
			# Extract the users data from the registry
			@debug_str += "Users:\n" if @debug_str
			sections = [
				"HKEY_LOCAL_MACHINE\\SAM\\SAM\\Domains\\Account\\Users",
				#"SAM/SAM/Domains/Builtin/Users"
			]
			sections.each do |section|
				reg_node = MIQRexml.findRegElement("#{section}\\Names", reg_doc.root)
				if reg_node
					reg_node.each_element_with_attribute(:keyname) do |e|
						username = e.attributes[:keyname]
						user_data = {}
						@debug_str += "  %s:\n" % username if @debug_str

						e.each_element(:value) do |e2|
							@debug_str += "    %s - %s - %s\n" % [e2.attributes[:name], e2.attributes[:type], e2.text] if @debug_str

							# Find the rest of the user's data based on the hex value stored in the type
							reg_node2 = MIQRexml.findRegElement("#{section}/#{e2.attributes[:type]}", reg_doc.root)
							if reg_node2
								reg_node2.each_element(:value) do |e3|
									@debug_str += "      %s - %s - %s\n" % [e3.attributes[:name], e3.attributes[:type], e3.text] if @debug_str
									if e3.attributes[:name] == "F"
										users_f = process_users_f(e3.text)

										# Do a sanity check on the return data
										if users_f.nil?
											# Set the user_data to nil to signify a parsing problem
											user_data = nil 
										elsif !user_data.nil?
											user_data.merge!(users_f)
										end
									elsif e3.attributes[:name] == "V"
										users_v = process_users_v(e3.text)
										
										# Do a sanity check on the return data
										if users_v.nil? || users_v['username'] != username
											# Set the user_data to nil to signify a parsing problem
											user_data = nil
                      $log.warn "Unable to process data for user account [#{username}]"
										elsif !user_data.nil?
											user_data.merge!(users_v)
										end
									end
								end
							end
						end

						# Get the pertinent data from out of that
						nh = { "name" => username }
						unless user_data.nil? || user_data.length == 0
							nh.merge!(
								"userid" => user_data['user_num'],
								"display_name" => user_data['fullname'],
								"comment" => user_data['comment'],
								"homedir" => user_data['homedir'],
								"enabled" => user_data['account_active'],
								"expires" => user_data['account_expires'].nil? ? "never" : user_data['account_expires'],
								"last_logon" => user_data['last_logon'],
								"groups" => Array.new
							)
							
							# Check for the SID in the permissions block by looking for a certain set of permissions.
							#   Checking is done in reverse, since the last permission set tends to be the right one.
							user_data['num_permissions'].downto(1) do |x|
								if user_data["perm#{x}_sid"] && ["D\000\002\000", "\004\000\002\000"].include?(user_data["perm#{x}_perms"])
									users_by_sids[user_data["perm#{x}_sid"]] = nh['name']
									break
                end
              end
            end
						@users << nh
					end
					@debug_str += "\n\n" if @debug_str
				end
			end
			
			# Extract the groups data from the registry
			@debug_str += "Groups:\n" if @debug_str
			sections = [
				"HKEY_LOCAL_MACHINE\\SAM\\SAM\\Domains\\Builtin\\Aliases",
				#"SAM/SAM/Domains/Builtin/Groups",
				"HKEY_LOCAL_MACHINE\\SAM\\SAM\\Domains\\Account\\Aliases",
				#"SAM/SAM/Domains/Account/Groups"
			]
			sections.each do |section|
				reg_node = MIQRexml.findRegElement("#{section}\\Names", reg_doc.root)
				if reg_node
					reg_node.each_element_with_attribute(:keyname) do |e|
						groupname = e.attributes[:keyname]
						group_data = {}
						@debug_str += "  %s:\n" % groupname if @debug_str

						e.each_element(:value) do |e2|
							@debug_str += "    %s - %s - %s\n" % [e2.attributes[:name], e2.attributes[:type], e2.text] if @debug_str

							# Find the rest of the group's data based on the hex value stored in the type
							reg_node2 = MIQRexml.findRegElement("#{section}/#{e2.attributes[:type]}", reg_doc.root)
							if reg_node2
								reg_node2.each_element(:value) do |e3|
									@debug_str += "      %s - %s - %s\n" % [e3.attributes[:name], e3.attributes[:type], e3.text] if @debug_str
									if e3.attributes[:name] == "C"
										groups_c = process_groups_c(e3.text)

										# Do a sanity check on the return data
										if groups_c.nil? || groups_c['group_name'] != groupname
											# Set the group_data to nil to signify a parsing problem
											group_data = nil
										elsif !group_data.nil?
											group_data.merge!(groups_c)
										end
									end					
								end
							end
						end

						# Get the pertinent data from out of that
						nh = { "name" => groupname }
						unless group_data.nil? || group_data.length == 0
							nh.merge!(
								"groupid" => group_data['group_num'],
								"comment" => group_data['group_desc']
							)
							
							nh['users'] = []
							group_data['sids'].each do |sid|
								if users_by_sids.include?(sid)
									# Add this user to the set of users for this group
									nh['users'] << users_by_sids[sid]
									
									# Add this group to the original user's set of groups
									found = @users.find { |u| u['name'] == users_by_sids[sid] }
									found['groups'] << nh['name'] if found
								end
              end
            end
						@groups << nh
					end
					@debug_str += "\n\n" if @debug_str
				end
			end
			
      # Force memory cleanup
      reg_doc = nil; GC.start

			# Dump the debug string to a file if we are collecting that data
			#File.open('C:/Temp/reg_extract_full_accounts.txt', 'w') { |f| f.write(@debug_str) } if @debug_str
		end

		def to_xml(doc = nil)
			doc = MiqXml.createDoc(nil) if !doc
			usersToXml(doc)
			groupsToXml(doc)
			doc
    end
		
		def usersToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
			unless @users.empty?
				node = doc.add_element("users")
				@users.each do |u|
					u_groups = u.delete('groups')
					user = node.add_element("user", u)
					
					u_groups.each do |g|
						user.add_element('member_of_group', {'name' => g}) 
					end unless u_groups.nil?
        end
			end
			doc
		end
    
		def groupsToXml(doc=nil)
			doc = MiqXml.createDoc(nil) if !doc
			unless @groups.empty?
				node = doc.add_element("groups")
				@groups.each do |g|
					g_users = g.delete('users')
					group = node.add_element("group", g)
					
					g_users.each do |u|
						group.add_element('member_users', {'name' => u}) 
					end unless g_users.nil?
        end
			end
			doc
		end
		
		# Definition derived from http://www.beginningtoseethelight.org/ntsecurity/#8603CF0AFBB170DD
		# \HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\%RID%\F (fixed length, 80)
		SAM_STRUCT_USERS_F = [
			'a8',			nil,										# UNKNOWN
			'Q',			'last_logon',						# Last logon (WinNT format), 0 if never logged on
			'a8',			nil,										# UNKNOWN
			'Q',			'last_pw_set',					# Password last set (WinNT format), 0 if not changed
			'Q',			'account_expires',			# Account expires (WinNT format), 0 if set not to expire
			'Q',			'last_wrong_pw',				# Last incorrect password (WinNT format), 0 if not
			'I',			'user_num',							# User number
			'a4',			nil,										# UNKNOWN
			'C',			'logon_ok_account_active',
																				# High nibble
																				#   Unsure - 0/2/6/8/A/C/E=pwd/username invalid
																				#   1/3/4=logonokay
																				#   5/7/D/F=Logon Message
																				#	    The system can not log you on due to the following error:
																				#	    The account used is an interdomain trust account. Use your global user
																				#				account or local user account to access this server.
																				#	    Please try again or consult your system administrator.
																				#   9/B=Logon Message
																				#	    The system can not log you on due to the following error: 
																				#	    The account used is a computer account. Use your global user account
																				#				or local user account to access this server. 
																				#	    Please try again or consult your system administrator.
																				# Low nibble
																				#   Account active - 0=active 1=not active.
																				#   Password required - 0=yes 4=no
																				#   0/2/4/6/8/A/C/E=logonokay - 1/2/5/7/9/B/D/F=accountdisabled/inactive
			'C',			'pw_never_expire',			# High nibble
																				#   UNKNOWN
																				# Low nibble
																				#   Password never expire - 0=secpoltime 2=never
																				#   For some unknown reason this value is set to 4 on a lockout and 0 on
																				#			unlocking. If the password is set never to expire the option to force
																				#			the user to change their password on next logon is greyed out.
																				#   2/3/6/7/A/B/E/F=Password never expires (2=GUI setting)
																				# 
																				#   0/2/8/A=logonokay
																				#   1/3/5/7/9/B/D/F=Logon Message
																				#     The system can not log you on due to the following error:
																				#     The account used is a server trust account. Use your global user
																				#				account or local user account to access this server.
																				#     Please try again or consult your system administrator.
																				#   4/6/C/E=logonokay - reset to X-4 though.
			'a2',			nil,										# UNKNOWN
			'S',			'country_code',					# Country code
			'a2',			nil,										# UNKNOWN
			'S',			'invalid_pw_count',			# Invalid password count, reset after a correct logon
			'S',			'num_logons',						# Number of logons, gets stuck at FF,FF
		]
		SIZEOF_SAM_STRUCT_USERS_F = BinaryStruct.sizeof(SAM_STRUCT_USERS_F)

		# Definition derived from http://www.beginningtoseethelight.org/ntsecurity/#D3BC3F5643A17823
		# \HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\%RID%\V (fixed length, 80)
		SAM_STRUCT_USERS_V_HEADER = [
			'a12',		nil,										# UNKNOWN
			'I',			'username_offset',			# Offset to username in V data section
			'I',			'username_length',			# Length of username in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'fullname_offset',			# Offset to fullname in V data section
			'I',			'fullname_length',			# Length of fullname in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'comment_offset',				# Offset to comment in V data section
			'I',			'comment_length',				# Length of comment in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'user_comment_offset',	# Offset to user comment in V data section
			'I',			'user_comment_length',	# Length of user comment in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'unknown1_offset',			# Offset to unknown1 in V data section
			'I',			'unknown1_length',			# Length of unknown1 in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'homedir_offset',				# Offset to homedir in V data section
			'I',			'homedir_length',				# Length of homedir in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'homedir_conn_offset',	# Offset to homedir connect in V data section
			'I',			'homedir_conn_length',	# Length of homedir connect in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'script_path_offset',		# Offset to script path in V data section
			'I',			'script_path_length',		# Length of script path in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'profile_path_offset',	# Offset to profile path in V data section
			'I',			'profile_path_length',	# Length of profile path in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'workstations_offset',	# Offset to workstations in V data section
			'I',			'workstations_length',	# Length of workstations in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'hours_allowed_offset',	# Offset to hours allowed in V data section
			'I',			'hours_allowed_length',	# Length of hours allowed in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'unknown2_offset',			# Offset to unknown2 in V data section
			'I',			'unknown2_length',			# Length of unknown2 in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'LM_pw_hash_offset',		# Offset to LM pw hash in V data section
			'I',			'LM_pw_hash_length',		# Length of LM pw hash in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'NT_pw_hash_offset',		# Offset to NT pw hash in V data section
			'I',			'NT_pw_hash_length',		# Length of NT pw hash in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'unknown3_offset',			# Offset to unknown3 in V data section
			'I',			'unknown3_length',			# Length of unknown3 in V data section
			'a4',			nil,										# UNKNOWN
			'I',			'unknown4_offset',			# Offset to unknown4 in V data section
			'I',			'unknown4_length',			# Length of unknown4 in V data section
			'a4',			nil,										# UNKNOWN

			'a72',		nil,										# UNKNOWN (WinXP, 2003, Vista, 2008)
			#'a52',		nil,										# UNKNOWN (Win2K)
			'I',			'num_permissions',			# Number of permissions
		]
		SIZEOF_SAM_STRUCT_USERS_V_HEADER = BinaryStruct.sizeof(SAM_STRUCT_USERS_V_HEADER)

		# Definition derived from http://www.beginningtoseethelight.org/ntsecurity/#D98C08727B08B0CB
		# \HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Aliases\%RID%\C (variable length) (custom groups)
		# \HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Builtin\Aliases\00000220\C (variable length) (builtin groups)
		SAM_STRUCT_GROUPS_C_HEADER = [
			'I',			'group_num',						# Group (user) number
			'a12',		nil,										# UNKNOWN
			'I',			'group_name_offset',		# Offset to group name in C data section
			'I',			'group_name_length',		# Length of group name in C data section
			'a4',			nil,										# UNKNOWN
			'I',			'group_desc_offset',		# Offset to group description in C data section
			'I',			'group_desc_length',		# Length of group description in C data section
			'a4',			nil,										# UNKNOWN
			'I',			'sids_offset',					# Offset to sids in C data section
			'I',			'sids_length',					# Length of sids in C data section
			'I',			'num_users',						# Number of users in sids data
			'a72',		nil,										# UNKNOWN (WinXP, 2003, Vista, 2008)
			#'a52',		nil,										# UNKNOWN (Win2K)
			'I',			'num_permissions',			# Number of permissions
		]
		SIZEOF_SAM_STRUCT_GROUPS_C_HEADER = BinaryStruct.sizeof(SAM_STRUCT_GROUPS_C_HEADER)
		
		# Definition derived from http://www.beginningtoseethelight.org/ntsecurity/#3C091C8F1BF2345C and
		# http://www.beginningtoseethelight.org/ntsecurity/#B1945830FA4449A5
		SAM_STRUCT_SID_HEADER = [
			'C', 'part1',											# First part of SID: S-[here]-?-...
			'C', 'num_sections',							# Number of 4-byte sections following second part of SID
			'a5', nil,												# UNKNOWN
			'C', 'part2',											# Second part of SID: S-?-[here]-...
    ]
		SIZEOF_SAM_STRUCT_SID_HEADER = BinaryStruct.sizeof(SAM_STRUCT_SID_HEADER)

		def self.rawBinaryToSids(data)
			sids = []
			while data && data.length > 0
				# Determine the full structure for this SID
				header = BinaryStruct.decode(data, SAM_STRUCT_SID_HEADER)
				sam_struct_sid_footer = []
				1.upto(header['num_sections']) { |x| sam_struct_sid_footer << 'I' << "section#{x}" }
				sam_struct_sid = [] + SAM_STRUCT_SID_HEADER + sam_struct_sid_footer
				
				# Get the parts and build the SID string
				sid_parts = BinaryStruct.decode(data, sam_struct_sid)
				sid = "S-#{sid_parts['part1']}-#{sid_parts['part2']}"
				'section1'.upto("section#{sid_parts['num_sections']}") do |x|
					break if sid_parts[x].nil?
					sid += '-' + sid_parts[x].to_s
				end
				sids << sid
				
				# Process the next SID
				data = data[BinaryStruct.sizeof(sam_struct_sid)..-1]
			end
			sids
		end

		def self.regBinaryToSid(data)
			rawBinaryToSids(MSRegHive.regBinaryToRawBinary(data))
		end
		
		def self.rawBinaryToRegBinary(a)
			b = ''
			a.each_byte { |c| b += "%02x," % c } unless a.nil?
			b.chop
    end

		def process_users_f(data)
			f = BinaryStruct.decode(MSRegHive.regBinaryToRawBinary(data), SAM_STRUCT_USERS_F)
			
			@debug_str += "        last_logon              - %s - " % f['last_logon'].to_s if @debug_str
			f['last_logon'] = process_users_f_date(f['last_logon'])
			@debug_str += "%s\n" % (f['last_logon'].nil? ? "Never" : f['last_logon']) if @debug_str
			
			@debug_str += "        last_pw_set             - %s - " % f['last_pw_set'].to_s if @debug_str
			f['last_pw_set'] = process_users_f_date(f['last_pw_set'])
			@debug_str += "%s\n" % (f['last_pw_set'].nil? ? "Not Change" : f['last_pw_set']) if @debug_str
			
			@debug_str += "        account_expires         - %s - " % f['account_expires'].to_s if @debug_str
			f['account_expires'] = process_users_f_date(f['account_expires'])
			@debug_str += "%s\n" % (f['account_expires'].nil? ? "Not set to expire" : f['account_expires']) if @debug_str
			
			@debug_str += "        last_wrong_pw           - %s - " % f['last_wrong_pw'].to_s if @debug_str
			f['last_wrong_pw'] = process_users_f_date(f['last_wrong_pw'])
			@debug_str += "%s\n" % (f['last_wrong_pw'].nil? ? "Not Wrong" : f['last_wrong_pw']) if @debug_str

			@debug_str += "        user_num                - %s\n" % f['user_num'].to_s if @debug_str

			@debug_str += "        logon_ok_account_active - 0x%02x\n" % f['logon_ok_account_active'] if @debug_str
			f['logon_ok'], f['account_active'] = process_users_f_logon_ok_account_active(f['logon_ok_account_active'])
			@debug_str += "          logon_ok              - %s\n" % f['logon_ok'].to_s if @debug_str
			@debug_str += "          account_active        - %s\n" % f['account_active'].to_s if @debug_str
			
			@debug_str += "        pw_never_expire         - 0x%02x\n" % f['pw_never_expire'] if @debug_str
			f['pw_never_expire'] = process_users_f_pw_never_expire(f['pw_never_expire'])
			@debug_str += "          pw_never_expire       - %s\n" % f['pw_never_expire'].to_s if @debug_str

			@debug_str += "        country_code            - %s - " % f['country_code'] if @debug_str
			f['country_code'] = process_users_f_country_code(f['country_code'])
			@debug_str += "%s\n" % (f['country_code'].nil? ? "Unknown" : f['country_code']) if @debug_str
					
			@debug_str += "        invalid_pw_count        - %s\n" % f['invalid_pw_count'].to_s if @debug_str
			@debug_str += "        num_logons              - %s\n" % f['num_logons'].to_s if @debug_str
			
			return f
    end
		
		def process_users_f_date(date)
			date == 0 || date == 0x7FFFFFFFFFFFFFFF ? nil : MSRegHive.wtime2time(date)
    end
		
		def process_users_f_logon_ok_account_active(data)
			logon_ok = data >> 4
			logon_ok = case logon_ok
			when 0, 2, 6, 8, 10, 12, 14 then false	#Username or Password invalid
			when 1, 3, 4 then	true									#Logon OK
			when 5, 7, 13, 15 then false						#Logon error message 1
			when 9, 11 then	false										#Logon error message 2
			else nil
			end

			account_active = data & 0x0F
			account_active = case account_active
			when 0 then	true												#Active; Password Required; Logon OK
			when 4 then true												#Password Not Required; Logon OK
			when 2, 6, 8, 10, 12, 14 then true			#Logon OK
			when 1 then false												#Not Active; Account Disabled / Inactive
			when 3, 5, 7, 9, 11, 13, 15 then false	#Account Disabled / Inactive"
			else nil
			end

			return logon_ok, account_active
    end
		
		def process_users_f_pw_never_expire(data)
			pw_never_expire = data & 0x0F
			pw_never_expire = case pw_never_expire
			when 0 then	true												#Secpol Time; Unlocking; Logon OK
			when 2 then true												#Never; GUI Setting; Password Never Expires; Logon OK
			when 8 then true												#Logon OK
			when 10 then true												#Password Never Expires; Logon OK
			when 3, 7, 11, 15 then true							#Password Never Expires; Logon Error Message"
			when 1, 5, 9, 13 then false							#Logon Error Message
			when 6, 14 then true										#Password Never Expires; Logon OK - Reset to X-4 though
			when 4 then true												#Lockout; Password Never Expires; Logon OK - Reset to X-4 though
			when 12 then true												#Logon OK - Reset to X-4 though
			else nil
			end

			return pw_never_expire
    end
		
		def process_users_f_country_code(data)
			country_code = case data
			when 0 then 'System Default'
			when 1 then 'United States'
			when 2 then 'Canada (French)'
			when 3 then 'Latin America'
			when 31 then 'Netherlands'
			when 32 then 'Belgium'
			when 33 then 'France'
			when 34 then 'Spain'
			when 39 then 'Italy'
			when 41 then 'Switzerland'
			when 44 then 'United Kingdom'
			when 45 then 'Denmark'
			when 46 then 'Sweden'
			when 47 then 'Norway'
			when 49 then 'Germany'
			when 61 then 'Australia'
			when 81 then 'Japan'
			when 82 then 'Korea'
			when 86 then 'China (PRC)'
			when 88 then 'Taiwan'
			when 99 then 'Asia'
			when 351 then 'Portugal'
			when 358 then 'Finland'
			when 785 then 'Arabic'
			when 972 then 'Hebrew'
			else nil
			end
			
			return country_code
    end
		
		def process_users_v(data)
			bin = MSRegHive.regBinaryToRawBinary(data)
			header_size = SIZEOF_SAM_STRUCT_USERS_V_HEADER
			v = BinaryStruct.decode(bin[0...header_size], SAM_STRUCT_USERS_V_HEADER)

			if @debug_str
				@debug_str += "        Header:\n"
				@debug_str += "          username_offset      - 0x%08x\n" % v['username_offset']
				@debug_str += "          username_length      - %s\n" % v['username_length'].to_s
				@debug_str += "          fullname_offset      - 0x%08x\n" % v['fullname_offset']
				@debug_str += "          fullname_length      - %s\n" % v['fullname_length'].to_s
				@debug_str += "          comment_offset       - 0x%08x\n" % v['comment_offset']
				@debug_str += "          comment_length       - %s\n" % v['comment_length'].to_s
				@debug_str += "          user_comment_offset  - 0x%08x\n" % v['user_comment_offset']
				@debug_str += "          user_comment_length  - %s\n" % v['user_comment_length'].to_s
				@debug_str += "          unknown1_offset      - 0x%08x\n" % v['unknown1_offset']
				@debug_str += "          unknown1_length      - %s\n" % v['unknown1_length'].to_s
				@debug_str += "          homedir_offset       - 0x%08x\n" % v['homedir_offset']
				@debug_str += "          homedir_length       - %s\n" % v['homedir_length'].to_s
				@debug_str += "          homedir_conn_offset  - 0x%08x\n" % v['homedir_conn_offset']
				@debug_str += "          homedir_conn_length  - %s\n" % v['homedir_conn_length'].to_s
				@debug_str += "          script_path_offset   - 0x%08x\n" % v['script_path_offset']
				@debug_str += "          script_path_length   - %s\n" % v['script_path_length'].to_s
				@debug_str += "          profile_path_offset  - 0x%08x\n" % v['profile_path_offset']
				@debug_str += "          profile_path_length  - %s\n" % v['profile_path_length'].to_s
				@debug_str += "          workstations_offset  - 0x%08x\n" % v['workstations_offset']
				@debug_str += "          workstations_length  - %s\n" % v['workstations_length'].to_s
				@debug_str += "          hours_allowed_offset - 0x%08x\n" % v['hours_allowed_offset']
				@debug_str += "          hours_allowed_length - %s\n" % v['hours_allowed_length'].to_s
				@debug_str += "          unknown2_offset      - 0x%08x\n" % v['unknown2_offset']
				@debug_str += "          unknown2_length      - %s\n" % v['unknown2_length'].to_s
				@debug_str += "          LM_pw_hash_offset    - 0x%08x\n" % v['LM_pw_hash_offset']
				@debug_str += "          LM_pw_hash_length    - %s\n" % v['LM_pw_hash_length'].to_s
				@debug_str += "          NT_pw_hash_offset    - 0x%08x\n" % v['NT_pw_hash_offset']
				@debug_str += "          NT_pw_hash_length    - %s\n" % v['NT_pw_hash_length'].to_s
				@debug_str += "          unknown3_offset      - 0x%08x\n" % v['unknown3_offset']
				@debug_str += "          unknown3_length      - %s\n" % v['unknown3_length'].to_s
				@debug_str += "          unknown4_offset      - 0x%08x\n" % v['unknown4_offset']
				@debug_str += "          unknown4_length      - %s\n" % v['unknown4_length'].to_s
				@debug_str += "          num_permissions      - %s\n" % v['num_permissions'].to_s
			end

			# Build middle section based on the num_permissions
			sam_struct_users_v_middle = []

			# Do a sanity check for the permissions section
			return nil if v['num_permissions'] > 100 || v['num_permissions'] <= 0

			sect_start = header_size
			'perm1'.upto("perm#{v['num_permissions']}") do |sect_name|
				bin_data = bin[sect_start + 2...sect_start + 4]
        return nil if bin_data.nil?
        sect_size = bin_data.unpack('S')[0]
				
				sam_struct_users_v_middle += [
					'a2',									nil,										# UNKNOWN
					'S',									"#{sect_name}_length",	# Length of block for permissions?
					'a4',									"#{sect_name}_perms",		# Permissions
					"a#{sect_size - 8}",	"#{sect_name}_sid",			# SID
				]
				
				sect_start += sect_size
      end

			sam_struct_users_v_middle += [
				'a16',    'admins_group_sidA',			# Administrators group SID
				'a16',    'admins_group_sidB',			# Administrators group SID again
			]

			# Build footer section based on sizes in header section
			sam_struct_users_v_footer = [
				'a%d' % v['username_length'],																																	'username',
				'a%d' % (v['fullname_offset']				- v['username_offset']			- v['username_length']),			nil,
				'a%d' % v['fullname_length'],																																	'fullname',
				'a%d' % (v['comment_offset']				- v['fullname_offset']			- v['fullname_length']),			nil,
				'a%d' % v['comment_length'],																																	'comment',
				'a%d' % (v['user_comment_offset']		- v['comment_offset']				- v['comment_length']),				nil,
				'a%d' % v['user_comment_length'],																															'user_comment',
				'a%d' % (v['unknown1_offset']				- v['user_comment_offset']	- v['user_comment_length']),	nil,
				'a%d' % v['unknown1_length'],																																	'unknown1',
				'a%d' % (v['homedir_offset']				- v['unknown1_offset']			- v['unknown1_length']),			nil,
				'a%d' % v['homedir_length'],																																	'homedir',
				'a%d' % (v['homedir_conn_offset']		- v['homedir_offset']				- v['homedir_length']),				nil,
				'a%d' % v['homedir_conn_length'],																															'homedir_conn',
				'a%d' % (v['script_path_offset']		- v['homedir_conn_offset']	- v['homedir_conn_length']),	nil,
				'a%d' % v['script_path_length'],																															'script_path',
				'a%d' % (v['profile_path_offset']		- v['script_path_offset']		- v['script_path_length']),		nil,
				'a%d' % v['profile_path_length'],																															'profile_path',
				'a%d' % (v['workstations_offset']		- v['profile_path_offset']	- v['profile_path_length']),	nil,
				'a%d' % v['workstations_length'],																															'workstations',
				'a%d' % (v['hours_allowed_offset']	- v['workstations_offset']	- v['workstations_length']),	nil,
				'a%d' % v['hours_allowed_length'],																														'hours_allowed',
				'a%d' % (v['unknown2_offset']				- v['hours_allowed_offset']	- v['hours_allowed_length']),	nil,
				'a%d' % v['unknown2_length'],																																	'unknown2',
				'a%d' % (v['LM_pw_hash_offset']			- v['unknown2_offset']			- v['unknown2_length']),			nil,
				'a%d' % v['LM_pw_hash_length'],																																'LM_pw_hash',
				'a%d' % (v['NT_pw_hash_offset']			- v['LM_pw_hash_offset']		- v['LM_pw_hash_length']),		nil,
				'a%d' % v['NT_pw_hash_length'],																																'NT_pw_hash',
				'a%d' % (v['unknown3_offset']				- v['NT_pw_hash_offset']		- v['NT_pw_hash_length']),		nil,
				'a%d' % v['unknown3_length'],																																	'unknown3',
				'a%d' % (v['unknown4_offset']				- v['unknown3_offset']			- v['unknown3_length']),			nil,
				'a%d' % v['unknown4_length'],																																	'unknown4',
      ]
			
			struct_sam_users_v = [] + SAM_STRUCT_USERS_V_HEADER + sam_struct_users_v_middle + sam_struct_users_v_footer
			v = BinaryStruct.decode(bin, struct_sam_users_v)

			@debug_str += "        Middle:\n" if @debug_str

			'perm1'.upto("perm#{v['num_permissions']}") do |sect_name|
				# Clean up the SID values
				v["#{sect_name}_sid"] = Accounts.rawBinaryToSids(v["#{sect_name}_sid"])[0]

				if @debug_str
					@debug_str += "          #{sect_name}_length#{' ' * (9 - sect_name.length + 5)}- %s\n" % v["#{sect_name}_length"].to_s
					@debug_str += "          #{sect_name}_perms#{' ' * (9 - sect_name.length + 6)}- %s\n" % Accounts.rawBinaryToRegBinary(v["#{sect_name}_perms"])
					@debug_str += "          #{sect_name}_sid#{' ' * (9 - sect_name.length + 8)}- %s\n" % v["#{sect_name}_sid"].to_s
				end
			end
			if @debug_str
				@debug_str += "          admins_group_sidA    - %s\n" % Accounts.rawBinaryToSids(v['admins_group_sidA'])
				@debug_str += "          admins_group_sidB    - %s\n" % Accounts.rawBinaryToSids(v['admins_group_sidB'])
			end
			
			# Clean up Unicode string fields
			v['username'].UnicodeToUtf8!.tr!("\0", "")
			v['username'] = nil if v['username'].length == 0
			v['fullname'].UnicodeToUtf8!.tr!("\0", "")
			v['fullname'] = nil if v['fullname'].length == 0
			v['comment'].UnicodeToUtf8!.tr!("\0", "")
			v['comment'] = nil if v['comment'].length == 0
			v['user_comment'].UnicodeToUtf8!.tr!("\0", "")
			v['user_comment'] = nil if v['user_comment'].length == 0
			v['homedir'].UnicodeToUtf8!.tr!("\0", "")
			v['homedir'] = nil if v['homedir'].length == 0
			v['homedir_conn'].UnicodeToUtf8!.tr!("\0", "")
			v['homedir_conn'] = nil if v['homedir_conn'].length == 0
			v['script_path'].UnicodeToUtf8!.tr!("\0", "")
			v['script_path'] = nil if v['script_path'].length == 0
			v['profile_path'].UnicodeToUtf8!.tr!("\0", "")
			v['profile_path'] = nil if v['profile_path'].length == 0
			v['workstations'].UnicodeToUtf8!.tr!("\0", "")
			v['workstations'] = nil if v['workstations'].length == 0
			
			if @debug_str
				@debug_str += "        Footer:\n"
				@debug_str += "          username             - '%s'\n" % v['username']
				@debug_str += "          fullname             - '%s'\n" % v['fullname']
				@debug_str += "          comment              - '%s'\n" % v['comment']
				@debug_str += "          user_comment         - '%s'\n" % v['user_comment']
				@debug_str += "          unknown1             - '%s'\n" % v['unknown1']
				@debug_str += "          homedir              - '%s'\n" % v['homedir']
				@debug_str += "          homedir_conn         - '%s'\n" % v['homedir_conn']
				@debug_str += "          script_path          - '%s'\n" % v['script_path']
				@debug_str += "          profile_path         - '%s'\n" % v['profile_path']
				@debug_str += "          workstations         - '%s'\n" % v['workstations']
				@debug_str += "          hours_allowed        - '%s'\n" % v['hours_allowed']
				@debug_str += "          unknown2             - '%s'\n" % v['unknown2']
				@debug_str += "          LM_pw_hash           - %s\n" % Accounts.rawBinaryToRegBinary(v['LM_pw_hash'])
				@debug_str += "          NT_pw_hash           - %s\n" % Accounts.rawBinaryToRegBinary(v['NT_pw_hash'])
				@debug_str += "          unknown3             - '%s'\n" % v['unknown3']
				@debug_str += "          unknown4             - '%s'\n" % v['unknown4']

				@debug_str += "\n\n"
			end
			
			return v
    end
		
		def process_groups_c(data)
			bin = MSRegHive.regBinaryToRawBinary(data)
			header_size = SIZEOF_SAM_STRUCT_GROUPS_C_HEADER
			c = BinaryStruct.decode(bin, SAM_STRUCT_GROUPS_C_HEADER)
			
			if @debug_str
				@debug_str += "        Header:\n"
				@debug_str += "          group_num         - %s\n" % c['group_num']
				@debug_str += "          group_name_offset - 0x%08x\n" % c['group_name_offset']
				@debug_str += "          group_name_length - %s\n" % c['group_name_length']
				@debug_str += "          group_desc_offset - 0x%08x\n" % c['group_desc_offset']
				@debug_str += "          group_desc_length - %s\n" % c['group_desc_length']
				@debug_str += "          sids_offset       - 0x%08x\n" % c['sids_offset']
				@debug_str += "          sids_length       - %s\n" % c['sids_length']
				@debug_str += "          num_users         - %s\n" % c['num_users']
				@debug_str += "          num_permissions   - %s\n" % c['num_permissions']
			end

			# Build middle section based on the num_permissions
			sam_struct_groups_c_middle = []

			# Do a sanity check for the permissions section
			return nil if c['num_permissions'] > 100 || c['num_permissions'] <= 0
			
			sect_start = header_size
			'perm1'.upto("perm#{c['num_permissions']}") do |sect_name|
				sect_size = bin[sect_start + 2...sect_start + 4].unpack('S')[0]

				sam_struct_groups_c_middle += [
					'a2',									nil,										# UNKNOWN
					'S',									"#{sect_name}_length",	# Length of block for permissions?
					'a4',									"#{sect_name}_perms",		# Permissions
					"a#{sect_size - 8}",	"#{sect_name}_sid",			# SID
				]
				
				sect_start += sect_size
      end

			sam_struct_groups_c_middle += [
				'a16',    'admins_group_sidA',			# Administrators group SID
				'a16',    'admins_group_sidB',			# Administrators group SID again
			]

			# Build footer section based on sizes in header section
			sam_struct_groups_c_footer = [
				'a%d' % c['group_name_length'],																											'group_name',
				'a%d' % (c['group_desc_offset'] - c['group_name_offset'] - c['group_name_length']), nil,
				'a%d' % c['group_desc_length'],																											'group_desc',
				'a%d' % (c['sids_offset']				- c['group_desc_offset'] - c['group_desc_length']),	nil,
				'a%d' % c['sids_length'],																														'sids'
      ]

			sam_struct_groups_c = [] + SAM_STRUCT_GROUPS_C_HEADER + sam_struct_groups_c_middle + sam_struct_groups_c_footer
			c = BinaryStruct.decode(bin, sam_struct_groups_c)

			@debug_str += "        Middle:\n" if @debug_str
			'perm1'.upto("perm#{c['num_permissions']}") do |sect_name|
				# Clean up the SID values
				c["#{sect_name}_sid"] = Accounts.rawBinaryToSids(c["#{sect_name}_sid"])[0]

				if @debug_str
					@debug_str += "          #{sect_name}_length#{' ' * (9 - sect_name.length + 2)}- %s\n" % c["#{sect_name}_length"].to_s
					@debug_str += "          #{sect_name}_perms#{' ' * (9 - sect_name.length + 3)}- %s\n" % Accounts.rawBinaryToRegBinary(c["#{sect_name}_perms"])
					@debug_str += "          #{sect_name}_sid#{' ' * (9 - sect_name.length + 5)}- %s\n" % c["#{sect_name}_sid"].to_s
				end
			end
			if @debug_str
				@debug_str += "          admins_group_sidA - %s\n" % Accounts.rawBinaryToSids(c['admins_group_sidA'])
				@debug_str += "          admins_group_sidB - %s\n" % Accounts.rawBinaryToSids(c['admins_group_sidB'])
			end
			
			# Clean up Unicode string fields
			c['group_name'].UnicodeToUtf8!.tr!("\0", "")
			c['group_name'] = nil if c['group_name'].length == 0
			c['group_desc'].UnicodeToUtf8!.tr!("\0", "")
			c['group_desc'] = nil if c['group_desc'].length == 0

			# Clean up SID values
			c['sids'] = Accounts.rawBinaryToSids(c['sids'])
			
			if @debug_str
				@debug_str += "        Footer:\n"
				@debug_str += "          group_name        - '%s'\n" % c['group_name']
				@debug_str += "          group_desc        - '%s'\n" % c['group_desc']
				@debug_str += "          sids              - #{c['sids'].length == 0 ? "None" : "%s#{"\n                              %s" * (c['sids'].length - 1)}" % c['sids']}\n"
				@debug_str += "\n\n"
			end
			
			return c
    end
	end
end
