require 'yaml'
require 'platform'

class VmsFromYaml
  @vms = {} 
  def initialize(file)
      raise "Missing file" unless File.file?(file)
      @vms = File.open(file)  { |yf| YAML::load( yf ) }
      if Platform::OS == :unix
        root_dir = (Platform::IMPL == :macosx) ? '/Volumes' : '/mnt'
        @vms.each do |vm, options|
          options["location"].gsub!('\\\\miq-websvr1', root_dir)
          options["location"].gsub!('\\', '/')
        end
      end
  end
  def find_vms_with_criteria(*args)
    args = Hash[*args.flatten]
    array = []
    match = 0  
    # Navigate one level down into the vm information  
    @vms.each_pair do |topkey, topvalue|
      # Check the provided arguments and filter only the ones that match   
      args.each_pair do |argAttr, argVal|
        if @vms[topkey][argAttr] == argVal then match = 1
        elsif @vms[topkey].has_key?(argAttr)
          match = 0
          break;      
        end
      end
    array << @vms[topkey] if match == 1
    end
  return array
  end
end
   

 ### test code  - uncomment to see how it works
#vmyml = VmsFromYaml.new('C:/Users/jrafaniello/Desktop/vms.yml')
#vm_array = vmyml.find_vms_with_criteria("vm_type", "vmware", "fs_type", "fat32")
#vm_array.each_index { |i| 
#  puts vm_array[i]["location"]
#  puts vm_array[i].inspect  
# }

#vm_array2 = vmyml.find_vms_with_criteria("disk_type", "ide")
#vm_array2.each_index { |i| puts vm_array[i].inspect }
 