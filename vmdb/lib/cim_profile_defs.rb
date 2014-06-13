require 'cim_association_defs'

require 'cim_profiles/cim_profile_base'
require 'cim_profiles/miq_profiles'
require 'cim_profiles/miq_ontap_profiles'

if __FILE__ == $0

  begin
    CimProfiles.check
    exit

    puts
    puts "storage_system_to_virtual_machine:"
    CimProfiles.storage_system_to_virtual_machine.dump("    ")
    # exit

    puts
    puts "CHECK ontap_filer:"
    CimProfiles.ontap_filer.check("    ")
    exit

    puts
    puts "base_storage_extent_to_top_storage_extent:"
    CimProfiles.base_storage_extent_to_top_storage_extent.dump("    ")
    # exit

    puts
    puts "CHECK base_storage_extent_to_top_storage_extent:"
    CimProfiles.base_storage_extent_to_top_storage_extent.check("    ")

  rescue => err

    puts err.to_s
    puts err.backtrace.join("\n")
    exit

  end

end
