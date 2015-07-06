
var param0 = "1 MB Template VM"
var param1 = "gm_test_vm"

var envelope = new SOAPEnvelope();
envelope.createNameSpace("xmlns:urn", "urn:ActionWebService");
envelope.setFunctionName("urn:EVMProvisionRequest");
envelope.addFunctionParameter("param0", param0, "xsd:string");
envelope.addFunctionParameter("param1", param1, "xsd:string");

var request = new SOAPRequest("https://192.168.252.111/vmdbws/api"); // XXX server
request.post(envelope);

var xml_str = request.getResponseDoc();
