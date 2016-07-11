module Api
  def self.normalized_attributes
    @normalized_attributes ||= {:time => {}, :url => {}, :resource => {}, :encrypted => {}}
  end
end
