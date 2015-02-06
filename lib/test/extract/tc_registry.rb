
$:.push("#{File.dirname(__FILE__)}/../../MiqVm")
$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}/../../metadata/MIQExtract")
require 'MiqVm'
require 'MIQExtract'
require 'miq-xml'
require 'digest/md5'
require 'test/unit'

$qaShare = File.join((Platform::IMPL == :macosx ? "/Volumes" : "/mnt"), "manageiq", "fleecing_test", "images", "virtual_machines")

module Extract
  class TestRegistry < Test::Unit::TestCase
    @@vmList = [
      {:vmName => File.join($qaShare, "vmware", "Windows Server 2003 Enterprise Edition/Windows Server 2003 Enterprise Edition.vmx"), :guestOS => "Windows"},
      {:vmName => File.join($qaShare, "vmware", "Debian 40 Server/debian40server.vmx"), :guestOS => "Linux"},
    ]

    def setup
      unless $log
        $:.push("#{File.dirname(__FILE__)}/../../util")
        require 'miq-logger'

        # Setup console logging
        $log = MIQLogger.get_log(nil, nil)
        $log.level = WARN
      end

      @vm = nil
    end

    def teardown
      begin
        @vm.unmount if @vm
      rescue IOError
      end
    end

    def test_scan_vm_metadata
      @@vmList.each { |f| scan_vm_metadata(f) }
    end

    def scan_vm_metadata(vmParms)
      fileName = vmParms[:vmName]
      return unless File.exist?(fileName)

      # Load VM object
      @vm = MiqVm.new(fileName)
      # Set the system fs handle
      @systemFs = @vm.vmRootTrees[0]
      assert_instance_of(MiqMountManager, @systemFs)
      assert_instance_of(String, @systemFs.pwd)

      # Validate GuestOS inforamtion
      assert_instance_of(String, @systemFs.guestOS)
      assert_match(@systemFs.guestOS, vmParms[:guestOS])

      @rootDriveLetter = @systemFs.pwd

      #walkSystem32Path()
      validateRegistryFiles() if @systemFs.guestOS == "Windows"
      validateMetadata()

      @vm.unmount if @vm
    end

    def validateMetadata()
      @systemFs.chdir(@rootDriveLetter)

      # Get handle to the Extract object
      vm = MIQExtract.new(@vm)

      # Call extract on each category
      # "ntevents"
      %w{vmconfig accounts software services system}.each do |c|
        xml = vm.extract(c)
        assert_not_nil(xml, "Category [#{c}] returned a nil instead of XML data.")

        xml = xml.to_xml
        validateVmXml(xml, c)
      end
    end

    def validateVmXml(xml, category)
      assert_not_nil(xml.root.attributes['version'])
      assert_not_nil(xml.root.attributes['created_on'])
      assert_not_nil(xml.root.attributes['display_time'])
      assert_instance_of(String, xml.root.attributes['display_time'])
      assert_instance_of(Fixnum, eval(xml.root.attributes['created_on']))

      # Use the as an exit point to generate the reference xml for testing
      #createReferenceXml(xml, category)

      compareVmXml(xml, category)
    end

    def compareVmXml(xml, category)
      refXml = loadReferenceXml(category)

      # Update and format the new XML for MD5 comparison
      xml.root.attributes['created_on']   = refXml.root.attributes['created_on']
      xml.root.attributes['display_time'] = refXml.root.attributes['display_time']

      # Calculate MD5s for each XML
      oldMD5 = generateMD5(xml)
      newMD5 = generateMD5(refXml)

      # Do further checking if MD5s don't match.
      # Note: It is ok if the MD5s do not match since there could be addtional white space or other
      #       valid differences in the xml markup that cause the documents to be different, yet
      #       actually contain the exact same data.
      unless oldMD5 == newMD5
        stats = {}
        xml.extendXmlDiff
        delta = xml.xmlDiff(refXml, stats)

        # If we find any changes write the diff xml out so it can be evaluated.
        xmlDiffPath = File.join(File.dirname(@vm.vmConfigFile), "test_data", category + "_diff.xml")
        unless stats[:adds].zero? && stats[:deletes].zero? && stats[:updates].zero?
          File.open(xmlDiffPath, "w") {|f| delta.write(f,0)}
        end

        # Test the results.
        errMsg = "VM Scan returned unexpected changes: [#{stats.inspect}].  See [#{xmlDiffPath}] for details."
        assert_equal(0, stats[:adds], errMsg)
        assert_equal(0, stats[:deletes], errMsg)
        assert_equal(0, stats[:updates], errMsg)
      end
    end

    def generateMD5(xml)
      md5Sig = Digest::MD5.new()
      xmlFormatted = ""
      xml.write(xmlFormatted, 0)
      md5Sig << xmlFormatted
      return md5Sig.hexdigest
    end

    def loadReferenceXml(category)
      # Load the reference XML file
      refXmlPath = File.join(File.dirname(@vm.vmConfigFile), "test_data", category + ".xml")
      MiqXml.loadFile(refXmlPath)
    end

    def createReferenceXml(xml, category)
      refXmlPath = File.join(File.dirname(@vm.vmConfigFile), "test_data", category + ".xml")
      File.open(refXmlPath,"w") {|f| xml.write(f,0)}
    end

    def walkSystem32Tree()
      fs = @systemFs
      currPath = fs.pwd
      [nil, "Windows", "System32", "config"].each do |p|
        currPath = File.join(currPath, p) unless p.nil?
        fs.chdir(currPath)
        fs.dirEntries(fs.pwd).each do |name|
          item = fs.fileDirectory?(name) ? "<DIR> #{name}" : name
          #$log.debug item
        end
      end
    end

    def validateRegistryFiles()
      fs = @systemFs
      filesFound = []
      currPath = File.join(@rootDriveLetter, "Windows", "System32", "config")
      fs.chdir(currPath)
      fs.dirEntries(fs.pwd).each { |name| filesFound << name.downcase unless fs.fileDirectory?(name) }
      %w{sam security default system software}.each do |hive|
        # Assert that we can list each one of the registry hive files
        assert(filesFound.include?(hive))

        # Check that all the registy hives are non zero byte files
        assert_not_equal(0, fs.fileSize(File.join(currPath, hive)))
      end
    end
  end
end
