require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
gem 'activerecord'


sqlip = "192.168.126.129"

class Vms < ActiveRecord::Base
end

#class Hosts < ActiveRecord::Base
#end

class SystemServices < ActiveRecord::Base
end

### open the Db connection
ActiveRecord::Base.establish_connection(
  :adapter    =>  "mysql",
  :host       =>  sqlip,
  :database   =>  "vmdb_development",
  :username   =>  "root"
 )

#svcs = SystemServices.find(:all, :select => "vm_id")
bad = 0
good = 0
Vms.find(:all).each { |vm|
  #print "."

  print "#{vm.id} "
#  vm.destroy unless (SystemServices.find(:first, :conditions => "vm_id = #{vm.id}")

  unless  (SystemServices.find(:first, :conditions => ["vm_id = ?", vm.id]))
    puts "\n Deleting vm #{vm.id}"
    vm.destroy
    bad = bad + 1
  end
  good = good + 1

}
puts "Bad = #{bad}"
puts "Good = #{good}"
