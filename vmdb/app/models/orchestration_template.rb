require 'digest/md5'
class OrchestrationTemplate < ActiveRecord::Base
  has_many :stacks, :class_name => "OrchestrationStack"

  # Find only by template content. Here we only compare md5 considering the table is expected
  # to be small and the chance of md5 collision is minimal.
  #
  def self.find_or_create_by_contents(hashes)
    hashes = [hashes] unless hashes.kind_of?(Array)
    md5s = hashes.collect { |hash| Digest::MD5.hexdigest(hash[:content]) }
    existing_templates = find_all_by_ems_ref(md5s).index_by(&:ems_ref)

    hashes.collect do |hash|
      template = existing_templates[hash[:ems_ref]]
      unless template
        hash.delete(:ems_ref)     # field :ems_ref is read only from outside
        template = create(hash)
        existing_templates[hash[:ems_ref]] = template
      end
      template
    end
  end

  def content=(c)
    super
    self.ems_ref = Digest::MD5.hexdigest(c)
  end

  # Check whether a template has been referenced by any stack. A template that is in use should be
  # considered read only
  def in_use?
    !stacks.empty?
  end

  # Find all in use and read-only templates
  def self.in_use
    joins(:stacks).uniq
  end

  # Find all not in use thus editable templates
  def self.not_in_use
    includes(:stacks).where(OrchestrationStack.arel_table[:orchestration_template_id].eq(nil))
  end

  private

  def ems_ref=(_md5)
    super
  end
end
