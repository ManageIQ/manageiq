describe Quadicons::UrlBuilder, :type => :helper do
  subject(:url) { Quadicons::UrlBuilder.new(record, helper).url }
end
