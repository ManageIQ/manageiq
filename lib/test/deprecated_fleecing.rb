# 
# test_fleecing.rb
# 
# Created on Dec 4, 2007, 4:25:53 PM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'rubygems'
require 'test/unit'
$:.push("#{File.dirname(__FILE__)}/../MiqVm")
$:.push("#{File.dirname(__FILE__)}/../metadata/util/win32")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../metadata/MIQExtract")
require 'rexml/document'
include REXML

require 'miq-xml'
require 'yaml'
require 'log4r'
include Log4r

class TestFleece < Test::Unit::TestCase
  def initLogger
    config = {
     :filename => "fleecing.log"
    }
    # create a logger named 'mylog'
    $log = Logger.new 'Fleecer'
    # You can use any Outputter here.
    #$log.outputters = Outputter.stdout
    $log.outputters = Log4r::FileOutputter.new("AutoFleecer", config)
    # log level order is DEBUG < INFO < WARN < ERROR < FATAL
    $log.level = Log4r::DEBUG
  end

  def cpLogToArtifacts
    srcLog = "./fleecing.log"
    unless ENV['CC_BUILD_ARTIFACTS'].nil?  
      puts "Cruise artifacts: #{ENV['CC_BUILD_ARTIFACTS']}"
      desLog = File.join(ENV['CC_BUILD_ARTIFACTS'], 'fleecing.log')
      puts "Copying '#{srcLog}' to '#{desLog}'"
      FileUtils.cp "#{srcLog}", "#{desLog}", :verbose => true
    end 
  end



  def loadPriorResults(prior)
    File.open("#{prior}" ) do |f|
      return Marshal.load(f)
    end
  end

  def saveResults(current)
    File.open("#{current}", "w") do |f|
      Marshal.dump($results, f)
    end
  end

  def findXpathsByCmd
    # @currCmd is "extract accounts, extract services, or extract software"
    # strip off the "extract " part
    # if the current command begins "extract...", strip it off
    cmd = @currCmd.gsub(/^extract(\s)/, '').strip if /extract/i =~ @currCmd
    # cmd should be accounts, services, or software, else, unknown
    #  $log.debug cmd
    xpaths = case
    when cmd == 'accounts': 
          ["//Accounts/Users/local/key/user", 
          "//Accounts/Users/local/key/key", 
          "//Accounts/Groups/local/key/group", 
          "//Accounts/Groups/local/key/key", 
          "//Accounts/Group_Accounts/local/key/key", 
          "//Accounts/Group_Accounts/local/key/group"]
    when cmd == 'services': 
          ["//Services/Linux_InitProcs/InitProc",
          "//Services/Win32_Services/key", 
          "//Services/Drivers/Kernel/key",
          "//Services/Drivers/FileSystem/key",
          "//Services/Drivers/Misc/key",
          "//OperatingSystem/Configuration/value",
          "//OperatingSystem/Networking/key[@keyname='NetworkCards']",
          "//OperatingSystem/Networking/key[@keyname='Rpc']",
          "//OperatingSystem/Networking/key[@keyname='Dhcp']", 
          "//OperatingSystem/Networking/key[@keyname='Tcpip']",
          "//OperatingSystem/EnvironmentVariables/key/value"]
    when cmd == 'software': 
          ["//Applications/Packages/Package", 
          "//OperatingSystem/Configuration/value",
          "//OperatingSystem/Networking/key[@keyname='NetworkCards']",
          "//OperatingSystem/Networking/key[@keyname='Rpc']",
          "//Applications/Patches/key/key", 
          "//Applications/Products/key/key", 
          "//Applications/App_Uninstall/key/key", 
          "//Applications/App_Paths/key/key",
          "//Applications/Run/key/key", 
          "//Applications/ProductKeys/key/key"]
    else
      $log.error "Unrecognized cmd type: #{cmd}"
      exit(1)
    end
  end


  def findVmsRecursively(dir)
    $log.info "Searching in #{dir}"
    fileTypes = []
    fileTypes.push(File.join(dir,"/**/*.vm{c,x}")) 
    fileTypes.push(File.join(dir,"/**/*.xen{2,3}.cfg"))
    fileList = []
    fileTypes.each do |ft|
      fileList += Dir.glob(ft)
    end
    return fileList
  end    

  def retrieveVmConfigs(args) 
    # $log.debug "retrieveVmConfigs:: args[0]: #{args[0]}"
    if args.length == 1
      @vms = findVmsRecursively(args[0].gsub(/\\/, '/'))
    else  
      # no path provided
      $log.info "retrieveVmConfigs:: Searching on Scratch and Scratch2"
      @vms = findVmsRecursively('//miq-websvr1/scratch2/vmimages/VMware')\
        +findVmsRecursively('//miq-websvr1/scratch/VMs')\
        +findVmsRecursively('//miq-websvr1/scratch/Xen Virtual Machines')    
#      @vms = findVmsRecursively('C:/Users/jrafaniello/Documents/My Virtual Machines')
    end
  end

  def validXml?(xml)
    begin
        REXML::Document.new(xml)
    rescue REXML::ParseException
      # Return nil if an exception is thrown
    end
  end
  
  def runVme
      miqvme = ("#{File.dirname(__FILE__)}/../../tools/MiqVmExplorer/MiqVmExplorer.rb")  
      $log.debug "runVme:: executing:  ruby '#{miqvme}' -v '#{@currFile}' do '#{@currCmd}'"

#### CODE TO PROPERLY QUOTE THE 'EXTRACT SOFTWARE' COMMAND SINCE WINDOWS DOESN'T HANDLE IT PROPERLY
#      puts "platform: #{RUBY_PLATFORM}"
#      case RUBY_PLATFORM
#      when /mswin32|mingw32/
#        puts "windows"
#        xml = `ruby "#{miqvme}" -v "#{@currFile}" do "#{@currCmd}"`
#      when /linux$/
#        puts "linux"
#        xml = `ruby "#{miqvme}" -v "#{@currFile}" do "#{@currCmd}"`
#      else
#        puts "runVme:: Unknown platform: #{RUBY_PLATFORM}"
#      end
      xml = `ruby "#{miqvme}" -v "#{@currFile}" do "#{@currCmd}"`
      # strip out the MiqVmExplorer stdout stuff and any whitespace
      #$log.debug "runVme:: MiqVmExplorer output: #{xml.match(/^MiqVmExplorer(.+)/)}"
      xml.sub!(/^MiqVmExplorer(.+)(\n)/, '').strip!
  end  

  def getVmData
      # store the cleaned up output of vm explorer and validate the xml 
      xml_data = runVme
      doc = validXml?(xml_data)
  end

  def writeXml(doc)
    filename = toXmlFileName(@currFile,@currCmd)
    $log.debug "writeXml:: Writing #{filename}"
    File.open(filename, "w") { |xmlFile| 
      xmlFile.puts doc
    }
  end
  
  def toXmlFileName(currFile,currCmd)
    #convert //miq-websvr1/scratch2/vmimages/VMware/AntiSpam/GFI.vmx to
    # miq-websvr1scratch2vmimagesVMwareAntiSpamGFI.xml

    convertedName = currFile.gsub(/(.vmx)|(.vmc)|(.cfg)/, "_#{currCmd}.xml").gsub!(/[\/\\\s:]/, "")
    #$log.debug "toXmlfileName:: convertedName = #{convertedName}"
    return convertedName
  end

  def getPriorResults(file, cmd, xpath)
    if $priorResults.nil? || $priorResults["#{file}"].nil? || $priorResults["#{file}"]["#{cmd}"].nil? || $priorResults["#{file}"]["#{cmd}"]["#{xpath}"].nil?
      return -1
    else
      return $priorResults["#{file}"]["#{cmd}"]["#{xpath}"]
    end
  end
  
  def cmdPassed?(node)
    passed = 1
    $log.debug "cmdPassed:: Beginning #{@currCmd} for #{@currFile}"
    currResultCnt = 0
    # if the document is nil or if the root node is nil, bail
    if node.nil? || node.root().nil?
      msg = "No Xml results in '#{@currFile}' : '#{@currCmd}'"
      $log.error "cmdPassed:: #{msg}"
      $errors.push("#{msg}")
      passed = 0
    else
      # lookup the xpaths based on the current command
      xpaths = findXpathsByCmd
      $log.debug "cmdPassed:: #{@currCmd} - xpaths: #{xpaths}"
      xpaths.each {|x|
        num = XPath.match(node, x).length
        currResultCnt += num
        $results["#{@currFile}"]["#{@currCmd}"]["#{x}"] = num
        
        prior = getPriorResults(@currFile, @currCmd, x)
        # if prior result has a value, verify it matches the current one
        unless prior < 0 
          if prior != num
            msg = "Prior: #{prior} != Curr: #{num} in '#{@currFile}' : '#{@currCmd}': '#{x}"
            $log.error "cmdPassed:: #{msg}"
            $errors.push("#{msg}")
            passed = 0
            #$log.warn "cmdPassed:: #{msg}"
            #$warn.push("#{msg}")
          end
        end
        $log.debug "cmdPassed:: #{@currCmd} - found: #{num} - new subtotal: #{currResultCnt} - xpath: #{x}"
      }
      if currResultCnt == 0
        msg = "Found #{currResultCnt} results in '#{@currFile}'' : '#{@currCmd}'"
        $log.error "cmdPassed:: #{msg}"
        $errors.push("#{msg}")
        passed = 0
      else
        $log.info "cmdPassed:: #{@currCmd} - Total: #{currResultCnt} in #{@currFile}"
      end
    end
    $log.info "passed: #{passed}"
    return passed
  end


  def test_fleece_all_vms
    ######################################################
    # Main method
    initLogger
    $log.info "Auto-Fleecer started at #{Time.now}"
    startTime = Time.now
    
    $errors = []
    $warn = []
    failedVms = []
    totalVms = 0
    #@commands = ["volumeinfo", "vgdisplay", "pvdisplay", "lvdisplay", "df", "extract accounts", "extract software", "extract services"]
    @commands = ['extract accounts','extract software','extract services']
    retrieveVmConfigs(ARGV)

    current = "currentResults.yaml"
    prior = "priorResults.yaml"

    if File.exists?(prior) && File.exists?(current)
        File.delete(prior) 
    end
    File.rename(current, prior) if File.exists?(current)
    $priorResults = loadPriorResults(prior) if File.exists?(prior)

    $results = {}
    @vms.each {|v| $log.info "#{v}"}
    $log.info ""
    @vms.each do |@currFile|
      invalid = 0
      vmStartTime = Time.now
      $log.info "Begin Fleecing: #{@currFile}"

      $results["#{@currFile}"] = {}
      @commands.each do |@currCmd| 
        $results["#{@currFile}"]["#{@currCmd}"] = {}
        xml_doc = getVmData
        # save the xml so we can review it afterwards
        writeXml(xml_doc) if $log.level == Log4r::DEBUG
        invalid += 1 if cmdPassed?(xml_doc) == 0
        $log.debug "After #{@currCmd}: invalid #{invalid}"
        #p $results.inspect
      end
      $log.debug "After all cmds: invalid #{invalid}"
      failedVms.push("#{@currFile}") if invalid > 0
      totalVms += 1
      $log.debug "failedVms: #{failedVms.length}"      
      $log.info "Finished #{@currFile} in #{Time.now - vmStartTime} seconds\n\n"
    end
    saveResults(current)
    $log.info "Auto-Fleecer finished at #{Time.now}"
    msg = "Finished #{totalVms} Vms in #{Time.now - startTime} seconds.\n#{failedVms.length} Vms failed to fleece." 
    $log.info msg
    puts msg
    cpLogToArtifacts
#    assert_equal(0,failedVms, "ENCOUNTERED #{failedVms} errors: see log for details")
    assert_equal(0,failedVms.length, "#{failedVms.length} Vms failed to fleece\n\n#{$errors.join("\n")}\n#{$warn.join("\n")}")
  end
end

