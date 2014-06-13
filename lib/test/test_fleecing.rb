$:.unshift File.join(File.dirname(__FILE__),'..','lib')
$:.push("#{File.dirname(__FILE__)}/../MiqVm")
$:.push("#{File.dirname(__FILE__)}/../metadata/util/win32")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../metadata/MIQExtract")
$:.push("#{File.dirname(__FILE__)}/../../tools/fleece_o_matic/app/models")

require 'rubygems'
require 'active_record'
require 'qa_test'
require 'fleece_result'
require 'fleece_category'
require 'test/unit'
require 'miq-xml'
require 'log4r'
require 'yaml'
require 'digest/md5'
require 'socket'
require 'zip/zip'
require 'zip/zipfilesystem' 
require 'find'
require 'fileutils'
require 'rake'

$prmtrs = ARGV.dup
$miqvme = "#{File.dirname(__FILE__)}/../../tools/MiqVmExplorer/MiqVmExplorer.rb"

class TestFleece < Test::Unit::TestCase

  #
  # Create a logger
  #
  def create_logger
    config = {:filename => "fleecing.log"}
    $log = Log4r::Logger.new 'Fleecer'
    $log.outputters = Log4r::FileOutputter.new("AutoFleecer", config)
    $log.level = Log4r::DEBUG
  end

  #
  # Copy a log to artifacts
  #
  def save_results
    $log.info "Auto-Fleecer finished at #{Time.now}"
    files = FileList["#{@test_result_directory}/*"]
    Zip::ZipFile.open("#{@test_result_directory}.zip", Zip::ZipFile::CREATE) { |zip| 
      files.each do |file|   
        begin
          zip.add("#{file}",file) 
        rescue Exception => err
          puts "ERROR:#{err.to_s}"
        end       
      end 
    }
    
    FileUtils.rm_r @test_result_directory
    unless ENV['CC_BUILD_ARTIFACTS'].nil?
      srclog = "./fleecing.log"
      puts "Cruise artifacts: #{ENV['CC_BUILD_ARTIFACTS']}"
      deslog = File.join(ENV['CC_BUILD_ARTIFACTS'], 'fleecing.log')
      puts "Copying '#{srclog}' to '#{deslog}'"
      FileUtils.cp "#{srclog}", "#{deslog}", :verbose => true
      srclog = "./#{@test_result_directory}.zip"
      puts "Cruise artifacts: #{ENV['CC_BUILD_ARTIFACTS']}"
      deslog = File.join(ENV['CC_BUILD_ARTIFACTS'], "#{@test_result_directory}.zip")
      puts "Copying '#{srclog}' to '#{deslog}'"
      FileUtils.cp "#{srclog}", "#{deslog}", :verbose => true
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
    if __FILE__ == $0
      @vms = find_vms_recursively($prmtrs[0].gsub(/\\/, '/'))
    else 
      if RUBY_PLATFORM.to_s =~ /linux/
        @vms = find_vms_recursively('/media/VM')
      else
        @vms = find_vms_recursively('//miq-websvr1/VM')
      end
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
  # Get probing Xpaths for each commands
  #
  def get_xpaths_for_given_cmd
    cmd = @currCmd.gsub(/^extract(\s)/, '').strip if /extract/i =~ @currCmd    
    xpaths = case
    when cmd == 'accounts': 
      ["//accounts/users/user", "//accounts/groups/group"]
    when cmd == 'services':
      ["//services/service"]
    when cmd == 'software':
      ["//software/applications/application", "//software/patches/patch"]
    else
      $log.error "Unrecognized cmd type: #{cmd}"
    end
  end
  
  # 
  # Convert //miq-websvr1/AntiSpam/GFI.vmx to miq-websvr1AntiSpamGFI.xml
  # 
  def to_xml_file_name(currFile,currCmd)  
    name = currFile.gsub(/(.vmx)/, "vmx_#{currCmd}.xml").gsub!(/[\/\\\s:]/, "") if currFile =~ /(.vmx)/
    name = currFile.gsub(/(.vmc)/, "vmc_#{currCmd}.xml").gsub!(/[\/\\\s:]/, "") if currFile =~ /(.vmc)/
    name = currFile.gsub(/(.cfg)/, "cfg_#{currCmd}.xml").gsub!(/[\/\\\s:]/, "") if currFile =~ /(.cfg)/
    return name
  end
  
  # 
  # Write XML data  
  #
  def write_xml(doc)
    filename = "#{@test_result_directory}/" + to_xml_file_name(@currFile,@currCmd)
    File.open(filename, "w") { |xmlFile| xmlFile.puts doc }  
  end 
    
  #
  # Executing MiqVmExplorer to fleece the request
  #
  def probe_vm_for_given_cmd 
    hashfunc = Digest::MD5.new  
    hashfunc << "#{@currFile}".gsub(/(\/\/miq-websvr1)|(\/media)|(\/home)|(\/asamborskiy)|([\/\\\s:])/, "").downcase
    hashfunc << "#{@currCmd}"    
    $results["#{@currFile}"]["#{@currCmd}"] = {}
    $results["#{@currFile}"]["#{@currCmd}"]["start"] = Time.now
    $results["#{@currFile}"]["#{@currCmd}"]["total"] = -1
    $results["#{@currFile}"]["#{@currCmd}"]["error"] = "" 
    $results["#{@currFile}"]["#{@currCmd}"]["debug"] = "" 
    
    $log.info " "  
    $log.info "Executing MiqVmExplorer '#{@currCmd}'"     
    str = `ruby "#{$miqvme}" -v "#{@currFile}" --loglevel=debug do "#{@currCmd}" 2>&1` 
    debugmsg = str.sub(/\<\?xml.+\<\/miq\>/m,'')
    xml = /\<\?xml\s.+\<\/miq\>/m.match(str)
    xml = xml[0] unless xml.nil? 
    if $? != 0 
      $log.error "MiqVmExplorer failed to fleece '#{@currCmd}': #{xml}"
      $log.debug "MiqVmExplorer debugging info: #{debugmsg}"
      $results["#{@currFile}"]["#{@currCmd}"]["error"] = "#{xml}"
      $results["#{@currFile}"]["#{@currCmd}"]["debug"] = "#{debugmsg}"
      $results["#{@currFile}"]["#{@currCmd}"]["hashsum"] = hashfunc.hexdigest
      $results["#{@currFile}"]["#{@currCmd}"]["stop"] = Time.now
      @failure = 1
      return -1
    else 
      begin
        @doc = REXML::Document.new(xml)
        if @doc  
          str = @doc.to_s.gsub(/(created_on=[\',\"](\d+)[\',\"])|(display_time=[\',\"]\w{4}-\w{2}-\w{5}:\w{2}:\w{3}[\',\"])/, "")
          hashfunc << str       
          $results["#{@currFile}"]["#{@currCmd}"]["hashsum"] = hashfunc.hexdigest
          write_xml(@doc) if $log.level == Log4r::DEBUG          
          
          if @doc.nil? || @doc.root().nil?
            $log.error "No Xml records in '#{@currCmd}'"
          else       	
            xpaths = get_xpaths_for_given_cmd
            counter = 0
            xpaths.each {|x|
              num = REXML::XPath.match(@doc, x).length
              counter += num
              $results["#{@currFile}"]["#{@currCmd}"]["#{x}"] = num
              $log.info "%-65s total:%5d subtotal:%5d"%[ x, num, counter ]
            }
            $results["#{@currFile}"]["#{@currCmd}"]["total"] = counter 
          end        
        end
        $results["#{@currFile}"]["#{@currCmd}"]["hashsum"] = hashfunc.hexdigest
        $results["#{@currFile}"]["#{@currCmd}"]["stop"] = Time.now  
        return 1      
      rescue Exception => err
        $log.error "#{err.to_s}"
        $log.error "Backtrace [#{err.backtrace.join("\n")}]"
        $results["#{@currFile}"]["#{@currCmd}"]["error"] = "#{err.to_s}" 
        $results["#{@currFile}"]["#{@currCmd}"]["debug"] = "#Backtrace: #{err.backtrace.join("\n")}" 
        return -1   
        @failure = 1             
      end 
    end
  end
   
  #
  # Fleecing VM
  #
  def fleece       
    #@commands = ['extract accounts','extract software','extract services', 'extract system']
    @commands = ['extract accounts','extract software','extract services']
    $results["#{@currFile}"] = {}    
    $results["#{@currFile}"]["start"] = Time.now
    @failure = 0
    @commands.each do |@currCmd| 
      cmdtime = Time.now    
      probe_vm_for_given_cmd   
      $log.info "Finished processing #{@currCmd} in #{Time.now-cmdtime} sec."
    end
    $results["#{@currFile}"]["stop"] = Time.now
 
    performance = $results["#{@currFile}"]["start"] - $results["#{@currFile}"]["stop"]
    $log.info "Finished fleecing VM in #{performance} sec."
    if @failure == 1
      @failedVms.push(@currFile)
    end
  end
  
  #
  # Save fleecing results in the database
  #
  def tst2db
    dtest = QaTest.create(
      :name        =>  "QA",
      :description =>  "Testing Framework",
      :build       =>  @cbuild,
      :started_on  =>  @test_started_on,
      :stopped_on  =>  @test_stopped_on,
      :test_host   =>  @test_host,
      :target_host =>  "",
      :subversion  => {:url =>$prmtrs[1], :branch =>$prmtrs[2], :revision=>$prmtrs[3]}
    ) 
    @vms.each do |vm|
      vm_id = vm.gsub(/(\/miq-websvr1)|(\/\/miq-websvr1)|(\/media)|(\/home)|(\/asamborskiy)/, "").downcase
      
      dvm = dtest.fleece_results.create(
        :name       => "#{vm_id}", 
        :filename   => "#{vm}", 
        :started_on => $results["#{vm}"]["start"], 
        :stopped_on => $results["#{vm}"]["stop"] 
      )
      @commands.each do |cd|
        dcd = dvm.fleece_categories.create(
          :category   => cd.gsub(/^extract(\s)/, '').strip,
          :started_on => $results["#{vm}"]["#{cd}"]["start"],
          :stopped_on => $results["#{vm}"]["#{cd}"]["stop"],
          :value      => $results["#{vm}"]["#{cd}"]["total"],
          :hashsum    => $results["#{vm}"]["#{cd}"]["hashsum"],
          :error      => $results["#{vm}"]["#{cd}"]["error"],
          :debug      => $results["#{vm}"]["#{cd}"]["debug"]
        )
      end      
    end 
  end 
  
  #
  # Detect VM drift
  # 
  def default_build_settings
    @test_host = Socket.gethostname
    @pbuild = 1
    test = QaTest.find(:all, :conditions => "test_host = \"#{@test_host}\"")
    test.each do |ctest|
      if ctest.build.to_f > @pbuild.to_f
        @pbuild  = ctest.build 
      end
    end
    if ENV['CC_BUILD_ARTIFACTS'].nil?
      @cbuild = (@pbuild.to_f + 0.00001).to_s
      $log.warn "Internal problems with the Cruiser Controller"
    else
      @cbuild = ENV['CC_BUILD_ARTIFACTS'].gsub(/^(.+)-/, '')
      if @pbuild.to_f >= @cbuild.to_f
        @cbuild = (@pbuild.to_f + 1.0).to_s
        $log.warn "Internal problems with the Cruiser Controller"
      end
    end 
    @test_result_directory = @test_host.to_s + @cbuild.to_s
    FileUtils.mkdir_p @test_result_directory
  end
  
  #
  # Fleecing available VMs
  #
  def fleece_vms
    @test_started_on = Time.now    
    temp = "#"
    @vms.each do |@currFile|
      @totalVms += 1
      $log.info "--------------------------------------------------------------"
      $log.info "            Fleecing Virtual Machine #{temp}#{@totalVms.to_s}:"
      $log.info "--------------------------------------------------------------" 
      $log.info "Fleecing #{@currFile}"
      puts "Fleecing VM #{temp}#{@totalVms.to_s} - #{@currFile}"
      fleece	
    end
    @test_stopped_on = Time.now
  end
  
  #
  # Test fleecing of all VMs - main method
  #
  def test_fleece_all_vms
    begin
      $warn      = []
      $errors    = [] 
      $results   = {} 
      
      @vms       = []                    
      @failedVms = [] 
      @totalVms  = 0    
      
      startime   = Time.now
      #
      # Start logger
      #		
      create_logger 
      $log.info "Auto-Fleecer started at #{startime}"   
      $log.info "Subversion: #{$prmtrs[1]}, Branch: #{$prmtrs[2]}, Revision: #{$prmtrs[3]}"
      
      #
      # Set default build 
      #      
      default_build_settings      
      
      #
      # Obtain VMs
      #
      obtain_vms
      
      #
      # Fleece all VMs
      #
      fleece_vms
       
      #
      # Send test into db
      #
      tst2db
      
      $log.info "----------------------------------------------------------------"
      $log.info "                         Results:                               "	
      $log.info "----------------------------------------------------------------"
      $log.info "Finished #{@totalVms} Vms in #{Time.now - startime} seconds."
      $log.info "#{@failedVms.length} Vms failed to fleece."
      
    rescue Exception => err
      $log.error "#{err.to_s}"
      $log.error "Backtrace [#{err.backtrace.join("\n")}]"      
    ensure
      #   
      # Save results
      #
      save_results
    end 
    drift = QaTest.detect_test_drift(@test_host, @cbuild, @test_host, @pbuild)
    assert_equal(0, drift.length, 
      "Drift between previous #{@pbuild} build and current #{@cbuild} build for test host #{@test_host}.\n 
       #{@failedVms.length} Vms failed to fleece in the current build.\n
       #{$errors.join("\n")}\n#{$warn.join("\n")}") 
  end
end
