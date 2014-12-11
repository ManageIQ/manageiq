// Functions used by MIQ for the dhtmlaccord control

//common function to pass ajax request to server
function miqAjaxRequest(itemId,path){
	if (miqCheckForChanges() == false) {
		return false;
	} else {
    miqJqueryRequest(path + '?id=' + itemId, {beforeSend: true, complete: true});
		return true;
	}
}

//function to pass ajax request to server for Policy Explorer
function miqAccordPolicySelect(itemId){
	return miqAjaxRequest(itemId,"/miq_policy/accordion_select");
}

//function to pass ajax request to server for PXE Explorer
function miqAccordPxeSelect(itemId){
	return miqAjaxRequest(itemId,"/pxe/accordion_select");
}


//function to pass ajax request to server for Automate Explorer
function miqAccordCustomizationSelect(itemId){
	return miqAjaxRequest(itemId,"/miq_ae_customization/accordion_select");
}

//function to pass ajax request to server for OPS Explorer
function miqAccordOpsSelect(itemId){
	return miqAjaxRequest(itemId,"/ops/accordion_select");
}

//function to pass ajax request to server for Report Explorer
function miqAccordReportSelect(itemId){
	return miqAjaxRequest(itemId,"/report/accordion_select");
}

//function to pass ajax request to server for VMs & Templates Explorer
function miqAccordVmOrTemplateSelect(itemId){
	return miqAjaxRequest(itemId,"/vm_or_template/accordion_select");
}

//function to pass ajax request to server for VMs & Templates Explorer
function miqAccordVmInfraSelect(itemId){
  return miqAjaxRequest(itemId,"/vm_infra/accordion_select");
}

//function to pass ajax request to server for VMs & Templates Explorer
function miqAccordVmCloudSelect(itemId){
  return miqAjaxRequest(itemId,"/vm_cloud/accordion_select");
}

//function to pass ajax request to server for Services Explorer
function miqAccordCTSelect(itemId){
	return miqAjaxRequest(itemId,"/catalog/accordion_select");
}

//function to pass ajax request to server for Services Explorer
function miqAccordSvcSelect(itemId){
	return miqAjaxRequest(itemId,"/service/accordion_select");
}

//function to pass ajax request to server, to remember tree states for Chargeback Explorer
function miqAccordChargebackSelect(itemId){
	return miqAjaxRequest(itemId,"/chargeback/accordion_select");	
}
