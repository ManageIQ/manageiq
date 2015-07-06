module MiqProvisionRedhatViaPxe::Cloning
  def prepare_for_clone_task
    super.merge(:clone_type  => :skeletal)
  end
end
