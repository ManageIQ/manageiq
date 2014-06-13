class ProxyTask < ActiveRecord::Base
  belongs_to :miq_proxy

  include ReportableMixin

  serialize :command
end
