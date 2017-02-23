module MiqProvision::Iso
  def iso_image
    @iso_image ||= begin
      klass, id = get_option(:iso_image_id).to_s.split('::')
      id.blank? ? nil : klass.constantize.find_by(:id => id)
    end
  end
end
