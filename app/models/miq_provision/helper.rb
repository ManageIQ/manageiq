module MiqProvision::Helper
  def hostname_cleanup(name)
    hostname_length = (source.platform == 'linux') ? 63 : 15
    name.strip.gsub(/ +|_+/, "-")[0, hostname_length]
  end
end
