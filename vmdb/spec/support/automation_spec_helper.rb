module AutomationSpecHelper

  # Find fields in automation XML file
  def sanitize_miq_ae_fields(fields)
    unless fields.nil?
      fields.each do |f|
        f["message"]       = @defaults_miq_ae_field[:message]      if f["message"].nil?
        f["substitute"]    = @defaults_miq_ae_field[:substitute]   if f["substitute"].blank?
        f["priority"]      = 1                                     if f["priority"].nil?
        unless f["collect"].blank?
          f["collect"] = f["collect"].first["content"]             if f["collect"].kind_of?(Array)
          f["collect"] = REXML::Text.unnormalize(f["collect"].strip)
        end
        ['on_entry', 'on_exit', 'on_error'].each { |k| f[k] = REXML::Text.unnormalize(f[k].strip) unless f[k].blank? }
        f["default_value"] = f.delete("content").strip             unless f["content"].nil?
        f["default_value"] = ""                                    if f["default_value"].nil?
        f["default_value"] = MiqAePassword.encrypt(f["default_value"]) if f["datatype"] == 'password'
      end
    end
    fields
  end

end

