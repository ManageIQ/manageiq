class MiqScvmmParsePowershell
  def output_to_attribute(winrm_output)
    attribute = ""
    winrm_output[:data].each do |d|
      attribute << d[:stdout] unless d[:stdout].nil?
    end
    # attribute.split("\r\n").first
    attribute.split("\r\n").last
  end
end
