def clean_up()
  $evm.root['Phase'] = "clean_up"
  $evm.log(:info, "********************** clean up ***************************")
  $evm.root['ae_result'] = "ok"
  $evm.root['Message'] = "cleaning up..."
end

clean_up()