#
# To change this template, choose Tools | Templates
# and open the template in the editor.


$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'miq_compare'
require 'yaml'
require 'miq_report'


class MiqCompareTest < ActiveSupport::TestCase

  @@TEMPLATE = './test/scriptRunner/vm_compare_template.yaml'
  @@TEMPLATE_DIR = './test/scriptRunner/'

  def build_compare(model, records = nil, all_sections = true, yaml = 'template')
    @compare = nil
    case model
    when 'Vm'
      records = [8,13] if records.nil?
      @ids = records
      filename = @@TEMPLATE
    else
      raise "Model #{model} not implemented yet!"
    end
    filename = yaml unless yaml == 'template'
    report_yaml = load_template(filename)

    options = {:ids => @ids}
    if all_sections
      includes = MiqCompare.sections(report_yaml)
      includes.each {|k, v| v[:fetch] = true}
      options[:include] = includes
    end
    @compare = MiqCompare.new(options, report_yaml)
  end

  def load_template(filename)
    raise "Template: #{filename} not found" unless File.exists?(filename)
    load_and_test_yaml(filename)
  end

  def load_and_test_yaml(filename)
    yaml_obj = YAML.load(File.read(filename))
    raise "Invalid Yaml file: {filename}\nYaml should begin '--- !ruby/object:MIQ_Report'" unless MIQ_Report == yaml_obj.class
    #assert_equal(MIQ_Report, yaml_obj.class, "Failure:  Expected MIQ_Report Yaml in file #{y_file}\nYaml should begin '--- !ruby/object:MIQ_Report'")
    return yaml_obj
  end

  def remove_dynamic_values_and_headers_from_master_list(arr)
    # get all the non-dynamic values : ie, only the tables and columns
    new_arr = []
    arr.each_slice(3) do |table, dynvalues, attributes|
      table = table[:name]
      new_arr << table
      new_arr << attributes.collect {|a| a[:name]} unless table.to_s[0..4] == '_tag_'
    end
    new_arr
  end

  def ids_from_model(model)
    (eval(model).find :all).collect {|v| v.id}
  end

  def random_ids(set, min, max = nil)
    # if no max provided or it's less than the min, set it to the min
    max = min if max.nil? || min > max
    ids = []
    all_exist_ids = set.is_a?(Array) ? set : ids_from_model(set)
    raise "Data set does not include enough ids: Is the database empty?" unless all_exist_ids.length >= 2
    # if max or min are larger than the set, reset them to the set length - 1
    min = all_exist_ids.length - 1 if min > all_exist_ids.length
    max = all_exist_ids.length - 1 if max > all_exist_ids.length

    num_ret_ids = rand(max - min + 1) + min

    num_ret_ids.times do
      rand_index = rand(all_exist_ids.length)
      rand_index = rand(all_exist_ids.length) until !ids.include?(all_exist_ids[rand_index])
      ids << all_exist_ids[rand_index]
    end

    ids
  end

  def test_master_list_for_test1_yaml_should_have_correct_col_order
    ids = random_ids('Vm', 2, 5)
    test_yaml = File.join(@@TEMPLATE_DIR, 'vm_compare_test1.yaml')
    build_compare('Vm', ids, true, test_yaml)

    exp_arr = [{:name=>:hardware, :header=>"Hardware"}, nil, [{:name=>:numvcpus, :header=>"CPUs"}, {:name=>:guest_os, :header=>"Guest OS"}], {:name=>:"hardware.guest_devices", :header=>"Devices"}, ["0", "0:0", "0:1", "0:2"], [{:name=>:address, :header=>"Address"}, {:name=>:mode, :header=>"Mode"}], {:name=>:_model_, :header=>"VM Properties"}, nil, [{:name=>:location, :header=>"Location"}, {:name=>:vendor, :header=>"Vendor"}, {:name=>:name, :header=>"Name"}]]
    exp_arr = remove_dynamic_values_and_headers_from_master_list(exp_arr)
    act_arr = remove_dynamic_values_and_headers_from_master_list(@compare.master_list)
    assert_equal(exp_arr, act_arr, "Expected array does not match the master list")
  end

  def test_master_list_should_have_correct_col_order
    ids = random_ids('Vm', 2, 5)
    build_compare('Vm', ids)

    exp_arr = [{:name=>:_model_, :header=>"VM Properties"}, nil, [{:name=>:name, :header=>"Name"}, {:name=>:vendor, :header=>"Vendor"}, {:name=>:location, :header=>"Location"}, {:name=>:last_scan_on, :header=>"Last Scan"}, {:name=>:retires_on, :header=>"Retires On"}, {:name=>:boot_time, :header=>"Boot Time"}, {:name=>:tools_status, :header=>"VMware Tools Status"}], {:name=>:hardware, :header=>"Hardware"}, nil, [{:name=>:guest_os, :header=>"Guest OS"}, {:name=>:numvcpus, :header=>"CPUs"}, {:name=>:memory_cpu, :header=>"Memory"}, {:name=>:bios, :header=>"BIOS"}, {:name=>:config_version, :header=>"Config Version"}, {:name=>:virtual_hw_version, :header=>"Virtual Hardware Version"}], {:name=>:"hardware.disks", :header=>"Disks"}, ["0", "0:0", "1:0"], [{:name=>:device_name, :header=>"Disks Device Name"}, {:name=>:filename, :header=>"Disks Filename"}, {:name=>:present, :header=>"Disks Present"}, {:name=>:start_connected, :header=>"Disks Start Connected"}, {:name=>:size, :header=>"Disks Size"}, {:name=>:free_space, :header=>"Disks Free Space"}, {:name=>:size_on_disk, :header=>"Disks Size On Disk"}], {:name=>:"hardware.nics", :header=>"Network Adapters"}, ["0", "1", "2"], [{:name=>:present, :header=>"NICs Present"}, {:name=>:start_connected, :header=>"NICs Start Connected"}, {:name=>:address, :header=>"NICs Address"}], {:name=>:users, :header=>"Users"}, ["backup", "bin", "daemon", "games", "gnats", "irc", "list", "lp", "mail", "man", "news", "nobody", "proxy", "root", "snmp", "sshd", "sync", "sys", "uucp", "vyatta", "www-data"], [{:name=>:enabled, :header=>"Enabled"}], {:name=>:groups, :header=>"Groups"}, ["adm", "audio", "backup", "bin", "cdrom", "crontab", "daemon", "dialout", "dip", "disk", "fax", "floppy", "games", "gnats", "irc", "kmem", "list", "lp", "mail", "man", "news", "nogroup", "operator", "plugdev", "proxy", "root", "sasl", "shadow", "src", "ssh", "staff", "sudo", "sys", "tape", "tty", "users", "utmp", "uucp", "video", "voice", "www-data", "xorp"], [], {:name=>:guest_applications, :header=>"Guest Applications"}, ["adduser", "apt", "apt-utils", "aptitude", "base-files", "base-passwd", "bash", "bind9-host", "bridge-utils", "bsdmainutils", "bsdutils", "busybox", "ca-certificates", "coreutils", "cpio", "cron", "debconf", "debconf-i18n", "debian-archive-keyring", "debianutils", "dhcp3-client", "dhcp3-common", "diff", "dmidecode", "dnsutils", "dpkg", "dselect", "e2fslibs", "e2fsprogs", "ed", "ethtool", "file", "findutils", "gcc-4.1-base", "gnupg", "gpgv", "grep", "groff-base", "grub", "gzip", "hostname", "ifrename", "ifupdown", "info", "initramfs-tools", "initscripts", "iproute", "ipsec-tools", "iptables", "iputils-ping", "iputils-tracepath", "klibc-utils", "klogd", "laptop-detect", "libacl1", "libadns1", "libatm1", "libattr1", "libbind9-0", "libblkid1", "libbz2-1.0", "libc6", "libcap1", "libcomerr2", "libcurl3", "libdb4.2", "libdb4.3", "libdb4.4", "libdevmapper1.02", "libdns22", "libedit2", "libexpat1", "libgcc1", "libgcrypt11", "libgdbm3", "libglib2.0-0", "libgmp3c2", "libgnutls13", "libgpg-error0", "libidn11", "libisc11", "libisccc0", "libisccfg1", "libiw28", "libklibc", "libkrb53", "libldap2", "liblocale-gettext-perl", "liblwres9", "liblzo1", "liblzo2-2", "libmagic1", "libncurses5", "libncursesw5", "libnetaddr-ip-perl", "libnewt0.52", "libopencdk8", "libpam-modules", "libpam-radius-auth", "libpam-runtime", "libpam0g", "libparted1.7-1", "libpcap0.8", "libpci2", "libpcre3", "libpopt0", "libreadline5", "libsablot0", "libsasl2", "libsasl2-2", "libselinux1", "libsensors3", "libsepol1", "libsigc++-1.2-5c2", "libsigc++-2.0-0c2a", "libslang2", "libsnmp-base", "libsnmp9", "libss2", "libssl0.9.8", "libstdc++6", "libsysfs2", "libtasn1-3", "libtasn1-3-bin", "libtext-charwidth-perl", "libtext-iconv-perl", "libtext-wrapi18n-perl", "libusb-0.1-4", "libuuid1", "libvolume-id0", "libwrap0", "lighttpd", "locales", "login", "logrotate", "lsb-base", "lsof", "makedev", "man-db", "manpages", "mawk", "mime-support", "mktemp", "module-init-tools", "modutils", "mount", "nano", "ncurses-base", "ncurses-bin", "net-tools", "netbase", "netcat", "ntpdate", "openbsd-inetd", "openssh-client", "openssh-server", "openssl", "openswan", "parted", "passwd", "pciutils", "perl", "perl-base", "perl-modules", "procps", "psmisc", "readline-common", "sed", "snmp", "snmpd", "sudo", "sysklogd", "sysv-rc", "sysvinit", "sysvinit-utils", "tar", "tasksel", "tasksel-data", "tcpd", "tcpdump", "traceroute", "tshark", "tzdata", "udev", "update-inetd", "util-linux", "vc2-base", "vc2-bgp", "vc2-cli", "vc2-config-migrate", "vc2-dhcp", "vc2-dhcp-relay-cli", "vc2-dhcp-server-cli", "vc2-dhcp-support", "vc2-firewall", "vc2-install", "vc2-iptables", "vc2-kernel", "vc2-nat", "vc2-nat-cli", "vc2-nat-xorp", "vc2-ntp", "vc2-ospf", "vc2-rip", "vc2-scripts", "vc2-serial", "vc2-vpn", "vc2-wanpipe", "vc2-wanpipe-dev", "vc2-xg", "vc2-xorp", "vim-common", "vim-tiny", "vlan", "wget", "whiptail", "wireshark-common", "zlib1g"], [], {:name=>:win32_services, :header=>"Win32 Services"}, [], [{:name=>:display_name, :header=>"Services Display Name"}], {:name=>:kernel_drivers, :header=>"Kernel Drivers"}, [], [{:name=>:display_name, :header=>"Kernel Drivers Display Name"}], {:name=>:filesystem_drivers, :header=>"File System Drivers"}, [], [{:name=>:display_name, :header=>"Filesystem Drivers Display Name"}], {:name=>:patches, :header=>"Patches"}, [], [], {:name=>:_tag_department, :header=>"Department"}, nil, [], {:name=>:_tag_customer, :header=>"Customer"}, nil, [], {:name=>:_tag_environment, :header=>"Environment"}, nil, [], {:name=>:_tag_function, :header=>"Function"}, nil, ["security"], {:name=>:_tag_location, :header=>"Location"}, nil, ["Chicago", "Fairfax"], {:name=>:_tag_owner, :header=>"Owner"}, nil, ["bhelgeson", "rmoore"], {:name=>:_tag_service_level, :header=>"Service Level"}, nil, [], {:name=>:_tag_power_state, :header=>"Power State"}, nil, ["off"]]
    exp_arr = remove_dynamic_values_and_headers_from_master_list(exp_arr)
    act_arr = remove_dynamic_values_and_headers_from_master_list(@compare.master_list)
    assert_equal(exp_arr, act_arr, "Expected array does not match the master list")
  end

  def test_results_objects_should_be_vms
    ids = random_ids('Vm', 2, 7)
    build_compare('Vm', ids)

    @compare.results.each do |k, h|
      assert_equal(Vm, h[:_object_].class, "Expected Vm object, received: #{h[:_object_].class.to_s}")
    end
  end

  #    def test_results_objects_are_hosts
  #      compare("vm_compare_test1.yaml", :vms)
  #      vm_results.each do |res|
  #        assert_equal(res[:_obj_].class.to_s, "Host")
  #      end
  #    end

  def test_results_tables_and_attributes_should_be_found_in_master_list
    ids = random_ids('Vm', 2, 5)
    build_compare('Vm', ids)

    section_names = {}
    @compare.master_list.each_slice(3) do |section, dyncolumns, columns|
      all_columns = columns.collect { |c| c[:name] }
      all_columns += dyncolumns unless dyncolumns.nil?
      section_names[section[:name]] = all_columns
    end

    # results is a hash of id=> {stuff}
    @compare.results.each do |id, table_attr_val_hash|
      table_attr_val_hash.each do |table, attr_val_hash|
        next if table.to_s[0,1] == '_' # Skip metadata hash values, such as _object_
        assert_send([section_names, :has_key?, table], "Master list does not include table #{table}")

        attr_val_hash.each do |attr, value|
          next if attr.to_s[0,1] == '_' # Skip metadata hash values, such as _match_
          assert_send([section_names[table], :include?, attr], "Master list does not include attribute: #{attr}")
        end
      end
    end
  end

  def test_results_should_contain_ids
    ids = random_ids('Vm', 2, 7)
    build_compare('Vm', ids)

    @compare.results.each_key {|k| assert_send [@ids, :include?, k]}
  end

  def test_add_record_should_add_records_to_end
    ids = random_ids('Vm', 2)
    build_compare('Vm', ids)

    new_ids = random_ids('Vm', 2, 7)
    new_ids.each do |id|
      # skip any ids already added
      next if @compare.ids.include?(id)
      @compare.add_record(id)
      assert_not_nil(@compare.results[id])
      assert_equal(id, @compare.ids.last)
    end
  end

  def test_remove_record_should_remove_record_result_and_maintain_ids_order
    ids = random_ids('Vm', 7)
    build_compare('Vm', ids)

    rem_ids = random_ids(@compare.ids, 5)
    rem_ids.each do |id|
      before_i = @compare.ids.index(id) - 1
      before_v = @compare.ids[before_i]
      after_i = @compare.ids.index(id) + 1
      after_v = @compare.ids[after_i]
      @compare.remove_record(id)
      assert_nil(@compare.results[id])
      assert_nil(@compare.ids.index(id))
      assert_equal(before_v, @compare.ids[before_i])   # prior value doesn't move
      assert_equal(after_v, @compare.ids[after_i - 1]) # next value is shifted one to the left
    end
  end

  #def test_add_section
  #build_compare(model, records = nil, all_sections = true
  #end

  def test_set_base_record_should_maintain_ids_original_order
    # [1,2,3,4,5]
    # set base 2 =>  [2,1,3,4,5]
    # set base 5 =>  [5,1,2,3,4]

    ids = random_ids('Vm', 8, 16)
    build_compare('Vm', ids)

    orig_ids = @compare.ids

    # select a subset of the random order of ids from the original ids to use as bases
    new_base_ids = random_ids(@compare.ids, 6, 8)
    new_base_ids.each do |id|
      # skip if id is the currect base
      next if id == @compare.ids[0]
      @compare.set_base_record(id)
      exp_ids = orig_ids.dup
      exp_ids.unshift(exp_ids.delete(id))  # delete the id and add it to the front
      assert_equal(exp_ids, @compare.ids)
      exp_ids = nil
    end
  end

  def test_add_or_remove_section_should_mark_section_checked_true_or_false
    ids = random_ids('Vm', 2)
    build_compare('Vm', ids, false)
    sections = MiqCompare.sections(load_template(@@TEMPLATE))
    sections.each do |k, v|
      next if k == :_model_
      assert(!@compare.include[k][:checked], "Checked flag '#{@compare.include[k][:checked]}' for section: #{k}: expected 'false'")
      @compare.add_section(k)
      assert(@compare.include[k][:checked], "Checked flag '#{@compare.include[k][:checked]}' for section: #{k}: expected 'true'")
    end

    sections.each do |k, v|
      next if k == :_model_
      assert(@compare.include[k][:checked], "Checked flag '#{@compare.include[k][:checked]}' for section: #{k}: expected 'true'")
      @compare.remove_section(k)
      assert(!@compare.include[k][:checked], "Checked flag '#{@compare.include[k][:checked]}' for section: #{k}: expected 'false'")
    end
  end




end # end class





# old setup
#@old_options = {:Vm=> {:ids=>["13", "25"], :include=>[{:attrs=>["name", "vendor", "location"], :mode=>"values", :name=>"vms", :squashed=>true, :title=>"Attributes", :added=>true, :checked=>true}]},
#  :Host=> {:ids=>["5", "3"], :include=>[{:attrs=>["name", "vmm_vendor", "vmm_version", "vmm_product", "vmm_buildnumber"], :mode=>"values", :name=>"hosts", :squashed=>true, :title=>"Attributes", :added=>true, :checked=>true}]}
#}
#@old_compare = compare_all
#@ci_types = @old_options.keys

#p @report.col_order
#  def compare_all
#    compare = {}
#    @old_options.each_key {|k| compare[k] = MiqCompare.new(@old_options[k], k.to_s) }
#    compare
#  end



#  def test_old_compare_input_attrs_equal_output_attrs
#    @ci_types.each do |ci|
#      input_attrs = @old_options[ci][:include][0][:attrs]
#      output_attrs = @old_compare[ci].results[0][ci.to_s.pluralize.downcase]
#      assert_equal(input_attrs.sort, output_attrs.sort)
#    end
#  end
#  def test_old_compare_objects_are_in_results
#    @ci_types.each do |ci|
#      @old_compare[ci].results[1..-1].each do |res|
#        assert_equal(res[:object].class.to_s, ci.to_s)
#      end
#    end
#  end
#  def teardown
#    @old_options, @new_options, @old_compare = nil
#  end
