$:.unshift File.join(File.dirname(__FILE__),'..','lib')
$:.push("#{File.dirname(__FILE__)}/../MiqVm")
$:.push("#{File.dirname(__FILE__)}/../metadata/util/win32")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../metadata/MIQExtract")

require 'rubygems'
require 'test/unit'
require 'rexml/document'
require 'miq-xml'
require 'yaml'
require 'log4r'
require 'mysql'
require 'digest/md5'

include REXML
include Log4r

$prmtrs = ARGV.dup
$miqvme = "#{File.dirname(__FILE__)}/../../tools/MiqVmExplorer/MiqVmExplorer.rb"

class TestFleece < Test::Unit::TestCase
  
  #
  # Create a logger
  #
  def create_logger
    config = {:filename => "fleecing.log"}
    $log = Logger.new 'Fleecer'
    $log.outputters = Log4r::FileOutputter.new("AutoFleecer", config)
    $log.level = Log4r::DEBUG
  end

  #
  # Copy a log to artifacts
  #
  def cp_log_to_artifacts
    $log.info "Auto-Fleecer finished at #{Time.now}"
    srclog = "./fleecing.log"
    unless ENV['CC_BUILD_ARTIFACTS'].nil?
      puts "Cruise artifacts: #{ENV['CC_BUILD_ARTIFACTS']}"
      deslog = File.join(ENV['CC_BUILD_ARTIFACTS'], 'fleecing.log')
      puts "Copying '#{srclog}' to '#{deslog}'"
      FileUtils.cp "#{srclog}", "#{deslog}", :verbose => true
    end 
  end
  
  #
  # Save current results
  #
  def save_results
    File.open("#{@report}", "w") do |f|
      Marshal.dump($results, f)
    end
  end

  #
  # Search for Virtual Machines
  #
  def find_vms_recursively(dir)
    $log.info "Searching for Virtual Machines in #{dir}"
    filetypes = []
    filetypes.push(File.join(dir,"/**/*.vm{c,x}")) 
    filetypes.push(File.join(dir,"/**/*.xen{2,3}.cfg"))
    filelist = []
    filetypes.each do |ft|
      filelist += Dir.glob(ft)
    end
    return filelist
  end    
  
  #
  # Obtain Virtual Machines
  #
  def obtain_vms		         
    if $prmtrs.length == 1 && __FILE__ == $0
      @vms = find_vms_recursively($prmtrs[0].gsub(/\\/, '/'))
    else 
      #@vms = find_vms_recursively('//miq-websvr1/scratch2/vmimages/VMware')\
      #     + find_vms_recursively('//miq-websvr1/scratch/VMs')\
      #     + find_vms_recursively('//miq-websvr1/scratch/Xen Virtual Machines') 
      @vms = find_vms_recursively('/home/asamborskiy/miq-websvr1/scratch2/vmimages/VMware')
    end
    
    $log.info "----------------------------------------------------------------"
    $log.info "                Discovered Virtual Machines:                    "	
    $log.info "----------------------------------------------------------------"	
    i = 0
    @vms.each {|v| 
      i = i + 1      
      temp = i.to_s + ". #{v}"
      $log.info temp
     }
     puts "#{i.to_s} Virtual Machines are discovered"   
  end
    
  #
  # Validate XML 
  #
  def valid_xml?(xml)
    begin
      REXML::Document.new(xml)
    rescue
      REXML::ParseException
    end
  end  
  
  # 
  # Get probing Xpaths for each commands
  #
  def get_xpaths_for_given_cmd
    cmd = @currCmd.gsub(/^extract(\s)/, '').strip if /extract/i =~ @currCmd
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
  
  # 
  # Convert //miq-websvr1/AntiSpam/GFI.vmx to miq-websvr1AntiSpamGFI.xml
  # 
  def to_xml_file_name(currFile,currCmd)
    name = currFile.gsub(/(.vmx)|(.vmc)|(.cfg)/, "_#{currCmd}.xml").
                    gsub!(/[\/\\\s:]/, "")
    return name
  end

  # 
  # Write XML data  
  #
  def write_xml(doc)
    filename = to_xml_file_name(@currFile,@currCmd)
    File.open(filename, "w") { |xmlFile| xmlFile.puts doc }
  end  
  
  
  #
  # Executing MiqVmExplorer to fleece the request
  #
  def probe_vm_for_given_cmd 

    hashfunc = Digest::MD5.new     
    
    $results["#{@currFile}"]["#{@currCmd}"] = {}
    $results["#{@currFile}"]["#{@currCmd}"]["total"] = -1
    
    $log.info " "  
    $log.info "Executing MiqVmExplorer '#{@currCmd}'"     
    xml = `ruby "#{$miqvme}" -v "#{@currFile}" do "#{@currCmd}" 2>&1`    
    xml.sub!(/^MiqVmExplorer(.+)(\n)/, '').strip! if xml  

    hashfunc << "#{@currFile}"
    
    if $? != 0
      $log.error "MiqVmExplorer failed to fleece '#{@currCmd}': #{xml}"
      hashfunc << "Can't fleece"
      @hashsum  += hashfunc.hexdigest
      return -1
    else 
      @doc = valid_xml?(xml)
      if @doc  
        str = @doc.to_s.gsub!(/(created_on=[\',\"](\d+)[\',\"])|(display_time=[\',\"]\w{4}-\w{2}-\w{5}:\w{2}:\w{3}[\',\"])/, "")
        hashfunc << str
      else
        $log.warn "Invalid XML"        
        hashfunc << "Invalid XML"
      end
        
      @hashsum  += hashfunc.hexdigest
      
      write_xml(@doc) if $log.level == Log4r::DEBUG          
      if @doc.nil? || @doc.root().nil?
        $log.error "No Xml records in '#{@currCmd}'"
      else       	
        xpaths = get_xpaths_for_given_cmd
        counter = 0
        xpaths.each {|x|
          num = XPath.match(@doc, x).length
          counter += num
          $results["#{@currFile}"]["#{@currCmd}"]["#{x}"] = num
          $log.info "%-65s total:%5d subtotal:%5d"%[ x, num, counter ]
        }
        $log.error "No records in '#{@currCmd}'" if counter == 0
        $results["#{@currFile}"]["#{@currCmd}"]["total"] = counter 
       end
    end       
  end
   
  #
  # Fleecing VM
  #
  def fleece       
    @commands = ['extract accounts','extract software','extract services', 'extract system']  
    @time = Time.now  
    @commands.each do |@currCmd| 
      cmdtime = Time.now    
      probe_vm_for_given_cmd    
      $log.info "Finished processing #{@currCmd} in #{Time.now-cmdtime} sec."
    end
    @performance = Time.now - @time
    $log.info "Finished fleecing VM in #{@performance} seconds"
  end
  
  #
  # 
  #
  def vm2db  
    begin    
      
      @accounts = $results["#{@currFile}"]["#{@commands[0]}"]["total"]
      @software = $results["#{@currFile}"]["#{@commands[1]}"]["total"]
      @services = $results["#{@currFile}"]["#{@commands[2]}"]["total"] 
      
      @dbh = Mysql.real_connect("localhost","root","smartvm","TestFleecingVMDB")
          
      i = 1
      res = @dbh.query("select id from VME")
      while row = res.fetch_row do
        tmp0 = row[0].to_i
        if tmp0 > i
          @dbh.query("update VME set id='#{i}' where id='#{row[0]}'")
        end    
        i += 1
      end
      res.free
     
      @dbh.query("insert into VME 
                   (id,
                    build,
                    name, 
                    time, 
                    accounts, 
                    software, 
                    services, 
                    performance,
                    hashsum) 
                  values 
                   ('#{i}',
                    '#{@build}',
                    '#{@currFile}',
                    '#{@time.to_s}',
                    '#{@accounts}',
                    '#{@software}',
                    '#{@services}',
                    '#{@performance}',
                    '#{@hashsum}')"
                ) if @dbh
    rescue Mysql::Error => e
    $log.error "Error message: #{e.error}" 
    ensure
       @dbh.close if @dbh
    end
  end  
  
  #
  # Detect VM drift
  # 
  def detect_vm_drift
    begin
      array = []
      @dbh = Mysql.real_connect("localhost","root","smartvm","TestFleecingVMDB")
    
      if @dbh
        res = @dbh.query("select build from VME")
        while row = res.fetch_hash do
          array.push(row["build"].to_i)
        end
        res.free
        
        if array.empty?
          $log.info "The VM database is empty"
        else
          array.sort
          @build = array[array.length - 1]
          
          cdata = []
          cres = @dbh.query("select * from VME where build = '#{@build}'")
        
          while row = cres.fetch_hash do
            cdata.push(row)
          end
            
          if @build == 1
            $log.info "There is only the current build in the database."
          else
          
          #
          # Detect previous build number
          #
            tmp = array.length - 1
            while tmp >= 0 && array[tmp] == @build
              tmp -= 1
            end 
            @previous_build = array[tmp]
        
            #
            # Fetch information from the database for the previous build
            #
            pdata = []
            pres = @dbh.query("select * from VME where build = '#{@previous_build}'")
            while row = pres.fetch_hash do
             pdata.push(row)
            end
       
            #
            # For each machine in the current build, search for it in the previous build
            #
            cdata.each{ |current|
              pdata.each{ |previous|
               if current['name'] == previous['name']
                 if current['hashsum'] != previous['hashsum']
                   $log.warn "WARNING: VM #{current['name']} has been changed!"
                   if current['accounts'].to_i !=previous['accounts'].to_i
                     $log.warn "In previous build VM #{current['name']} had #{previous['accounts']} accounts, now it has #{current['accounts']} accounts "
                   end
                    if current['software'].to_i != previous['software'].to_i
                     $log.warn "In previous build VM #{current['name']} had #{previous['software']} software, now it has #{current['software']} software "
                   end
                    if current['services'].to_i!=previous['services'].to_i
                     $log.warn "In previous build VM #{current['name']} had #{previous['services']} services, now it has #{current['services']} services "
                   end
                 end
               end
              }
            }
            
            pres.free
          end         
          cdata.each{ |current|    
            if current['accounts'].to_i == -1 || current['software'].to_i == -1 || current['services'].to_i == -1
              $log.warn "Can not fleece VM #{current['name']}"
            end
          }
          cres.free 
        end
      end
    rescue Mysql::Error => e
    $log.error "Error message: #{e.error}" 
    ensure
       @dbh.close if @dbh
    end    
  end
  
  
  #
  # Fleecing available VMs
  #
  def fleece_vms
    array = []
    @dbh = Mysql.real_connect("localhost","root","smartvm","TestFleecingVMDB")
    res = @dbh.query("select build from VME")
    while row = res.fetch_row do
      array.push(row[0].to_i)
    end
    res.free      
    if array.empty?
      @build = 1
    else
      array.sort
      @build = array[array.length - 1] + 1
    end
    @dbh.close if @dbh
    
   
    
    temp = "#"
    @vms.each do |@currFile|
      @totalVms += 1
      $log.info "--------------------------------------------------------------"
      $log.info "            Fleecing Virtual Machine #{temp}#{@totalVms.to_s}:"
      $log.info "--------------------------------------------------------------" 
      $log.info "Fleecing #{@currFile}"
      $results["#{@currFile}"] = {}
      puts "Fleecing VM #{temp}#{@totalVms.to_s}"
      @hashsum = ''
      fleece	
      vm2db
    end
    detect_vm_drift
  end

  #
  # Test fleecing of all VMs - main method
  #
  def test_fleece_all_vms
    $warn      = []
    $errors    = [] 
    $results   = {} 
    
   
    @hashsum = ''      
   
    
    @vms       = []                    
    @failedVms = [] 
    @totalVms  = 0    
    @startTime = Time.now 
    @report   = "report.yaml"    
      
    #
    # Start logger
    #		
    create_logger 
    $log.info "Auto-Fleecer started at #{@startTime}"     	

    #
    # Obtain VMs
    #
    obtain_vms

    #
    # Fleece all VMs
    #
    fleece_vms

    #
    # Save results
    #
    save_results
   		
    #
    # Copy log to artifacts
    #
    cp_log_to_artifacts

    assert_equal(0,@failedVms.length, 
                "#{@failedVms.length} Vms failed to fleece\n
	         #{$errors.join("\n")}\n#{$warn.join("\n")}")
    
    $log.info "----------------------------------------------------------------"
    $log.info "                         Results:                               "	
    $log.info "----------------------------------------------------------------"
    $log.info "Finished #{@totalVms} Vms in #{Time.now - @startTime} seconds."
    $log.info "#{@failedVms.length} Vms failed to fleece."
  end
end
