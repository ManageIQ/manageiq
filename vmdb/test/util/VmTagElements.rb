require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
gem 'activerecord'

sqlip = "192.168.126.129"

class Vms < ActiveRecord::Base
end

class Hosts < ActiveRecord::Base
end

class SystemServices < ActiveRecord::Base
end

$COUNTGOOD = 0
$COUNTBAD = 0
$TASKSBAD = ""

def handle_tag_failure(vm, name, where)
  $COUNTBAD + 1
#  $TASKSBAD = $TASKSBAD + "#{vm.id.to_s} #{name.to_s} #{where.to_s}"
end

### open the Db connection
ActiveRecord::Base.establish_connection(
  :adapter    =>  "mysql",
  :host       =>  sqlip,
  :database   =>  "vmdb_development",
  :username   =>  "root"
)

(Vm.find :all).each { |vm|
  ["accounts", "vmconfig", "software", "services", "system"].each { |name|
    lastFull = vm.last_full_state_by_name(name)
    unless lastFull.nil?
      begin
        doc = lastFull.full_doc
      rescue
        handle_tag_failure(vm, name, "full_doc")
        break
      end
    else
      handle_tag_failure(vm, name, "last_full_state")
      break
    end

    begin
      unless doc.nil?
  #      puts vm.id
  #      puts name
  #      puts vm.nil?
  #      puts doc.nil?
  #      puts doc.inspect
  #      print "#{vm.inspect} \n"

        puts "Tagging #{vm.id} - #{name}"
        vm.tag_elements(doc)
        $COUNTGOOD = $COUNTGOOD + 1
      else
        handle_tag_failure(vm, name, "nil doc")
        break
      end
    rescue
      break
    end
  }
}
puts "Tagged: #{$COUNTGOOD}"
puts "Vms with No state or XML: #{$COUNTBAD}"
puts $TASKSBAD

