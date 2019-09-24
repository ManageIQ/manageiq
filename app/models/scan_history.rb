class ScanHistory < ApplicationRecord
  belongs_to :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id

  include FilterableMixin
end
