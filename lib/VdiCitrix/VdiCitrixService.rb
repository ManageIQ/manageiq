$:.push("#{File.dirname(__FILE__)}")

class VdiCitrixService
  def initialize(options)
    @plugin_version = options[:plugin_version]

    case @plugin_version.to_i
    when 4
      require 'VdiCitrixService_ver4'
      extend VdiCitrixService::Version4
    when 5
      require 'VdiCitrixService_ver5'
      extend VdiCitrixService::Version5
    end
  end

  def add_user_to_desktop_and_pool(user_name, user_sid, desktop_pool_name, desktop_pool_id, desktop_name, desktop_id)
    configure_ps_command(:add_user_to_desktop_and_pool, user_name, user_sid, desktop_pool_name, desktop_pool_id, desktop_name, desktop_id)
  end

  def remove_user_from_desktop(user_name, user_sid, desktop_pool_name, desktop_pool_id, desktop_name, desktop_id)
    configure_ps_command(:remove_user_from_desktop, user_name, user_sid, desktop_pool_name, desktop_pool_id, desktop_name, desktop_id)
  end

  def add_user_to_desktop_pool(user_name, user_sid, desktop_pool_name, desktop_pool_id)
    configure_ps_command(:add_user_to_desktop_pool, user_name, user_sid, desktop_pool_name, desktop_pool_id)
  end

  def remove_user_from_desktop_pool(user_name, user_sid, desktop_pool_name, desktop_pool_id)
    configure_ps_command(:remove_user_from_desktop_pool, user_name, user_sid, desktop_pool_name, desktop_pool_id)
  end

  def remove_desktop_pool(desktop_pool_name, desktop_pool_id)
    configure_ps_command(:remove_desktop_pool, desktop_pool_name, desktop_pool_id)
  end

  def modify_desktop_pool(desktop_pool_name, desktop_pool_id, settings)
    configure_ps_command(:modify_desktop_pool, desktop_pool_name, desktop_pool_id, settings)
  end

  def create_desktop_pool(settings)
    configure_ps_command(:create_desktop_pool, settings)
  end

  def configure_ps_command(ps_method_name, *args)
    ps_script = self.ps_methods_load_plugin
    ps_script += self.ps_methods

    args.each_with_index do |arg, idx|
      if arg.kind_of?(Hash)
        ps_script += "$ps_arg#{idx} = @{\n"
        arg.each {|k,v| ps_script += "'#{k}' = '#{v.to_s}'\n"}
        ps_script += "}\n"
      elsif arg.kind_of?(Array)
        ps_script += "$ps_arg#{idx} = @(\n"
        arg.each_with_index {|v, idx| ps_script += (idx+1 == arg.length) ? "'#{v}'\n" : "'#{v}',\n"}
        ps_script += ")\n"
      else
        ps_script += "$ps_arg#{idx} = '#{arg}'\n"
      end
    end
    ps_script += "$result = #{ps_method_name}"
    args.each_with_index {|arg, idx| ps_script += " $ps_arg#{idx}"}

    ps_script += <<-PS_SCRIPT
    $true
    PS_SCRIPT
    ps_script
  end

  def ps_methods_load_plugin
    <<-PS_SCRIPT
    function load_citrix_plugin($raise_error = $true, $log_result = $true) {
      $plugin_version = $null

      $requested_plugins = @("XDCommands", "Citrix.Broker.Admin.V1", "Citrix.Host.Admin.V1")
      foreach ($plugin in $requested_plugins) {if ((Get-PSSnapin -Name $plugin -ErrorAction SilentlyContinue) -eq $null) {Add-PSSnapin $plugin -ErrorAction SilentlyContinue}}

      if ((Get-PSSnapin     -Name "Citrix.Broker.Admin.V1" -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 5}
      elseif ((Get-PSSnapin -Name "XDCommands"             -ErrorAction SilentlyContinue) -ne $null) {$plugin_version = 4}

      if ($plugin_version -eq $null -and $raise_error -eq $true) {throw "No Citrix plug-in found"}
      if ($log_result) {
        if ($plugin_version -eq $null) {miq_logger "warn" "Citrix XenDesktop plugin not found"}
        else                           {miq_logger "info" "Citrix XenDesktop version $($plugin_version) plugin found"}
      }

      return $plugin_version
    }
    $plugin_version = load_citrix_plugin
    PS_SCRIPT
  end
end
