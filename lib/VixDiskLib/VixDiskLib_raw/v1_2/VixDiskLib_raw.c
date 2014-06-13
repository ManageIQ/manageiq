/*
 * Ruby module bridge to VixDiskLib 1.2.
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <string.h>
#ifdef HAVE_OPENSSL_EVP_H
#include <openssl/evp.h>    // needed for VixDiskLib_Open bug workaround
#endif

#include "vixDiskLib.h"
#undef EXTERN
#undef NORETURN
#include "ruby.h"

#define VIXDISKLIB_VERSION_MAJOR 1
#define VIXDISKLIB_VERSION_MINOR 2

/*
 * Read a string value from a hash using the given key.
 */
#define GET_HASHED_STRING(hash, key, dflt) \
         ((tval = rb_hash_aref(hash, key)) == Qnil ? dflt : RSTRING_PTR(StringValue(tval)))
/*
 * Read a numeric value from a hash using the given key.
 */     
#define GET_HASHED_INT(hash, key, dflt) \
         ((tval = rb_hash_aref(hash, key)) == Qnil ? dflt : NUM2INT(tval))

/*
 * Create a class constant based on the given object-like macro.
 */
#define INTDEF2CONST(klass, intdef) \
         rb_define_const(klass, #intdef, INT2NUM(intdef))

/*
 * Create a Ruby symbol based on the given C string.
 */
#define STR2SYM(str)    ID2SYM(rb_intern((str)))

#define LOGLEVEL_VERBOSE  (verbose ? log_info : log_debug)

static const char *class_name     = "VixDiskLib_raw";
static const char *exception_name = "VixDiskLibError_raw";
static VALUE cVixDiskLib_raw;
static VALUE rb_eVixDiskLibError;
static int   verbose;
/*
 * The ruby logger instance used by this code to log messages.
 */
static VALUE logger;

/*
 * Log levels for logger.
 */
static VALUE log_info;
static VALUE log_warn;
static VALUE log_error;
static VALUE log_debug;

static void
rb_log(VALUE level, const char *fmt, ...)	{
	va_list ap;
	char *p, *np;
	int n, size = 128;
	
	if (logger == Qnil) {
		return;
	}
	
	if ((p = malloc(size)) == NULL)	{
	  return;
	}
	
	va_start(ap, fmt);
	n = vsnprintf(p, size, fmt, ap);
	va_end(ap);
	
	if (n >= size)	{
		size = n + 1;
		if ((np = realloc(p, size)) == NULL) {
			free(p);
			return;
		}
		p = np;
	
		va_start(ap, fmt);
		vsnprintf(p, size, fmt, ap);
		va_end(ap);
	}
	
	rb_funcall(logger, level, 1, rb_str_new2(p));
	free(p);
}

/*
 * Check the VixDiskLib return code and raise a Ruby exception,
 * with descriptive text, if there was an error.
 */
static void
vix_check(VixError err, const char *method) {
  char *msg, msg_buf[1024];
    
  if (VIX_FAILED(err))    {
    msg = VixDiskLib_GetErrorText(err, NULL);
    (void)strncpy(msg_buf, msg, sizeof(msg_buf)-1);
    msg_buf[sizeof(msg_buf) - 1] = '\0';
    VixDiskLib_FreeErrorText(msg);
    rb_raise(rb_eVixDiskLibError, "%s.%s (errcode=%d): %s", class_name, method, VIX_ERROR_CODE(err), msg_buf);
  }
}

/*
 * Unlike logger above, this logging facility is used by the VixDisk library
 * to log messages. It is the ruby binding to the log functions that can be
 * passed into VixDiskLib_Init.
 */
#define VDL_INFO    0
#define VDL_WARN    1
#define VDL_ERROR   2

static  VALUE   vdl_info_log_proc;
static  VALUE   vdl_warn_log_proc;
static  VALUE   vdl_error_log_proc;

static void
vdl_log_proxy(int level, const char *fmt, va_list args)    {
  char    buf[1024];
  VALUE   log_proc = Qnil;
  VALUE   rsm;
    
  switch(level)   {
    case VDL_INFO:
      log_proc = vdl_info_log_proc;
      break;
    case VDL_WARN:
      log_proc = vdl_warn_log_proc;
      break;
    case VDL_ERROR:
      log_proc = vdl_error_log_proc;
      break;
  }
  if (NIL_P(log_proc)) return;
    
  vsnprintf(buf, 1024, fmt, args);
  rsm = rb_str_new2(buf);
  rb_funcall(log_proc, rb_intern("call"), 1, rsm);
}

static void
vdl_log_info_proxy(const char *fmt, va_list args)    {
  vdl_log_proxy(VDL_INFO, fmt, args);
}

static void
vdl_log_warn_proxy(const char *fmt, va_list args)    {
  vdl_log_proxy(VDL_WARN, fmt, args);
}

static void
vdl_log_error_proxy(const char *fmt, va_list args)    {
  vdl_log_proxy(VDL_ERROR, fmt, args);
}

static void
vdl_free(void *p)	{
	free(p);
}

/*******************************************************/
/***    Implementation of Ruby Method Bindings   *******/
/*******************************************************/

/*
 * Symbol hash keys for connection parameters.
 */
static VALUE vmxSpec_sym;
static VALUE serverName_sym;
static VALUE credType_sym;
static VALUE userName_sym;
static VALUE password_sym;
static VALUE cookie_sym;
static VALUE key_sym;
static VALUE port_sym;

/*
 * Symbol hash keys for VixDiskLibInfo.
 */
static VALUE biosGeoCylinders_sym;
static VALUE biosGeoHeads_sym;
static VALUE biosGeoSectors_sym;
static VALUE physGeoCylinders_sym;
static VALUE physGeoHeads_sym;
static VALUE physGeoSectors_sym;
static VALUE capacity_sym;              // also used for VixDiskLibCreateParams
static VALUE adapterType_sym;           // also used for VixDiskLibCreateParams
static VALUE numLinks_sym;
static VALUE parentFileNameHint_sym;

/*
 * Symbol hash keys for VixDiskLibCreateParams
 */
static VALUE diskType_sym;
static VALUE hwVersion_sym;
// adapterType_sym defined above
// capacity_sym defined above


/*
 * The "attach" class method.
 */
static VALUE
vdl_attach(VALUE rSelf, VALUE rParentHandle, VALUE rChildHandle)   {
  VixDiskLibHandle        *pvParentDiskHandle;
  VixDiskLibHandle        *pvChildDiskHandle;
  VixError                 vixError;
    
  Data_Get_Struct(rParentHandle, VixDiskLibHandle, pvParentDiskHandle);
  Data_Get_Struct(rChildHandle,  VixDiskLibHandle, pvChildDiskHandle);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.attach: status=[starting] parentDiskHandle=[0x%x], childDiskHandle=[0x%x]", class_name, *pvParentDiskHandle, *pvChildDiskHandle);
  vixError = VixDiskLib_Attach(*pvParentDiskHandle, *pvChildDiskHandle);
  vix_check(vixError, "attach");
	rb_log(LOGLEVEL_VERBOSE, "%s.attach: status=[complete] parentDiskHandle=[0x%x], childDiskHandle=[0x%x]", class_name, *pvParentDiskHandle, *pvChildDiskHandle);
	
  return Qnil;
}

/*
 * The "checkRepair" class method.
 */
static VALUE
vdl_checkRepair(VALUE rSelf, VALUE rConnection, VALUE rFilename, VALUE rRepair)   {
  VixDiskLibConnection    *pvConnection;
  VixError                 vixError;
  char                    *vFilename;
  Bool                     vRepair;

  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
  vFilename = RSTRING_PTR(StringValue(rFilename));
  vRepair   = RTEST(rRepair) ? TRUE : FALSE;

  rb_log(LOGLEVEL_VERBOSE, "%s.checkRepair: status=[starting] connection=[0x%x], filename=[%s], repair=[%s]", class_name, *pvConnection, vFilename, vRepair ? "true" : "false");
  vixError = VixDiskLib_CheckRepair(*pvConnection, vFilename, vRepair);
  vix_check(vixError, "checkRepair");
  rb_log(LOGLEVEL_VERBOSE, "%s.checkRepair: status=[complete] connection=[0x%x], filename=[%s], repair=[%s]", class_name, *pvConnection, vFilename, vRepair ? "true" : "false");

  return Qnil;
}

/*
 * The "cleanup" class method.
 */
static VALUE
vdl_cleanup(VALUE rSelf, VALUE rConnectParams) {
  VixDiskLibConnectParams vConnectParams;
  VixError                vixError;
  VALUE                   tval;
  VALUE                   rArray;
  uint32                  numCleanedUp = 0;
  uint32                  numRemaining = 0;
    
  Check_Type(rConnectParams, T_HASH);

  memset(&vConnectParams, 0, sizeof(VixDiskLibConnectParams));
  vConnectParams.serverName         = GET_HASHED_STRING(rConnectParams, serverName_sym, NULL);
  vConnectParams.port               = GET_HASHED_INT(   rConnectParams, port_sym,       0);
  vConnectParams.credType           = GET_HASHED_INT(   rConnectParams, credType_sym,   0);
  vConnectParams.creds.uid.userName = GET_HASHED_STRING(rConnectParams, userName_sym,   NULL);
  vConnectParams.creds.uid.password = GET_HASHED_STRING(rConnectParams, password_sym,   NULL);
    
	rb_log(log_debug, "%s.cleanup: vmxSpec    = %s", class_name, vConnectParams.vmxSpec);
	rb_log(log_debug, "%s.cleanup: credType   = %d", class_name, vConnectParams.credType);
	
	rb_log(LOGLEVEL_VERBOSE, "%s.cleanup: status=[starting] server=[%s], port=[%d], userid=[%s]", class_name, vConnectParams.serverName, vConnectParams.port, vConnectParams.creds.uid.userName);
  vixError = VixDiskLib_Cleanup(&vConnectParams, &numCleanedUp, &numRemaining);
  vix_check(vixError, "cleanup");
	
	rb_log(LOGLEVEL_VERBOSE, "%s.cleanup: status=[complete] numCleanedUp=[%d], numRemaining=[%d]", class_name, numCleanedUp, numRemaining);
	
  rArray = rb_ary_new();
  rb_ary_push(rArray, rb_Integer(numCleanedUp));
  rb_ary_push(rArray, rb_Integer(numRemaining));
  return rArray;
}


/*
 * The "clone" class method.
 */
static VALUE
vdl_clone(VALUE rSelf, VALUE rTargetConnection, VALUE rTargetPath, 
                       VALUE rSourceConnection, VALUE rSourcePath,
                       VALUE rCreateParams,  VALUE rOverwrite)   {
                          
  VixDiskLibConnection    *pvTargetConnection, *pvSourceConnection;
  char                    *vTargetPath, *vSourcePath;
  VixDiskLibCreateParams  vCreateParams;
  VixError                vixError;
  VALUE                   tval;
  Bool                    vOverwrite;
    
  Check_Type(rCreateParams, T_HASH);
    
  vCreateParams.diskType     = GET_HASHED_INT(rCreateParams, diskType_sym,    VIXDISKLIB_DISK_MONOLITHIC_FLAT);
  vCreateParams.adapterType  = GET_HASHED_INT(rCreateParams, adapterType_sym, VIXDISKLIB_ADAPTER_UNKNOWN);
  vCreateParams.hwVersion    = GET_HASHED_INT(rCreateParams, hwVersion_sym,   VIXDISKLIB_HWVERSION_CURRENT);
  vCreateParams.capacity     = GET_HASHED_INT(rCreateParams, capacity_sym,    0);
    
  Data_Get_Struct(rTargetConnection, VixDiskLibConnection, pvTargetConnection);
  Data_Get_Struct(rSourceConnection, VixDiskLibConnection, pvSourceConnection);
    
  vTargetPath = RSTRING_PTR(StringValue(rTargetPath));
  vSourcePath = RSTRING_PTR(StringValue(rSourcePath));
  vOverwrite  = RTEST(rOverwrite) ? TRUE : FALSE;
    
	rb_log(log_debug, "%s.clone: overwrite                = %d",   class_name, vOverwrite);
	rb_log(log_debug, "%s.clone: createParams.diskType    = %d",   class_name, vCreateParams.diskType);
	rb_log(log_debug, "%s.clone: createParams.adapterType = %d",   class_name, vCreateParams.adapterType);
	rb_log(log_debug, "%s.clone: createParams.hwVersion   = %d",   class_name, vCreateParams.hwVersion);
	rb_log(log_debug, "%s.clone: createParams.capacity    = %d",   class_name, vCreateParams.capacity);

  rb_log(LOGLEVEL_VERBOSE, "%s.clone: status=[starting] targetConnection=[0x%x], targetPath=[%s], sourceConnection=[0x%x], sourcePath=[%s]", class_name, *pvTargetConnection, vTargetPath, *pvSourceConnection, vSourcePath);
  vixError = VixDiskLib_Clone(*pvTargetConnection, vTargetPath, *pvSourceConnection, vSourcePath, &vCreateParams, NULL, NULL, vOverwrite);
  vix_check(vixError, "clone");
  rb_log(LOGLEVEL_VERBOSE, "%s.clone: status=[complete] targetConnection=[0x%x], targetPath=[%s], sourceConnection=[0x%x], sourcePath=[%s]", class_name, *pvTargetConnection, vTargetPath, *pvSourceConnection, vSourcePath);
	
  return Qnil;
}

/*
 * The "combine" class method.
 */
static VALUE
vdl_combine(VALUE rSelf, VALUE rDiskHandle, VALUE rLinkOffsetFromBottom, VALUE rNumLinksToCombine) {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                vixError;
  uint32                  vLinkOffsetFromBottom;
  uint32                  vNumLinksToCombine;

  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  vLinkOffsetFromBottom = NUM2UINT(rLinkOffsetFromBottom);
  vNumLinksToCombine    = NUM2UINT(rNumLinksToCombine);

  rb_log(LOGLEVEL_VERBOSE, "%s.combine: status=[starting] diskHandle=[0x%x], linkOffsetFromBottom=[%d], numLinksToCombine=[%d]", class_name, *pvDiskHandle, vLinkOffsetFromBottom, vNumLinksToCombine);
  vixError = VixDiskLib_Combine(*pvDiskHandle, vLinkOffsetFromBottom, vNumLinksToCombine, NULL, NULL);
  vix_check(vixError, "combine");
  rb_log(LOGLEVEL_VERBOSE, "%s.combine: status=[complete] diskHandle=[0x%x], linkOffsetFromBottom=[%d], numLinksToCombine=[%d]", class_name, *pvDiskHandle, vLinkOffsetFromBottom, vNumLinksToCombine);

  return Qnil;
}

/*
 * The "close" class method.
 */
static VALUE
vdl_close(VALUE rSelf, VALUE rDiskHandle) {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                vixError;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);

	rb_log(LOGLEVEL_VERBOSE, "%s.close: status=[starting] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  vixError = VixDiskLib_Close(*pvDiskHandle);
  vix_check(vixError, "close");
	rb_log(LOGLEVEL_VERBOSE, "%s.close: status=[complete] diskHandle=[0x%x]", class_name, *pvDiskHandle);
	
  return Qnil;
}

/*
 * The "connect" class method.
 */
static VALUE
vdl_connect(VALUE rSelf, VALUE rConnectParams) {
  VixDiskLibConnectParams vConnectParams;
  VixDiskLibConnection   *pvConnection;
  VixError                vixError;
  VALUE                   tval;
    
  Check_Type(rConnectParams, T_HASH);
  
  memset(&vConnectParams, 0, sizeof(VixDiskLibConnectParams));    
  vConnectParams.vmxSpec            = GET_HASHED_STRING(rConnectParams, vmxSpec_sym, NULL);
  vConnectParams.serverName         = GET_HASHED_STRING(rConnectParams, serverName_sym, NULL);
  vConnectParams.port               = GET_HASHED_INT(rConnectParams, port_sym, 0);
  vConnectParams.credType           = GET_HASHED_INT(rConnectParams, credType_sym, 0);
  vConnectParams.creds.uid.userName = GET_HASHED_STRING(rConnectParams, userName_sym, NULL);
  vConnectParams.creds.uid.password = GET_HASHED_STRING(rConnectParams, password_sym, NULL);
    
	rb_log(log_debug, "%s.connect: vmxSpec    = %s", class_name, vConnectParams.vmxSpec);
	rb_log(log_debug, "%s.connect: credType   = %d", class_name, vConnectParams.credType);
    
  if ((pvConnection = malloc(sizeof(VixDiskLibConnection))) == NULL)    {
    rb_raise(rb_eNoMemError, "%s.connect: out of memory", class_name);
  }
  
	rb_log(LOGLEVEL_VERBOSE, "%s.connect: status=[starting] server=[%s], port=[%d], userid=[%s]", class_name, vConnectParams.serverName, vConnectParams.port, vConnectParams.creds.uid.userName);
    
  vixError = VixDiskLib_Connect(&vConnectParams, pvConnection);
  if (VIX_FAILED(vixError))    {
    free(pvConnection);
    vix_check(vixError, "connect");
  }
    
	rb_log(LOGLEVEL_VERBOSE, "%s.connect: status=[complete] connection=[0x%x]", class_name, *pvConnection);
    
  return Data_Wrap_Struct(rSelf, 0, vdl_free, pvConnection);
}


/*
 * The "connectEx" class method.
 */
static VALUE
vdl_connectEx(VALUE rSelf, VALUE rConnectParams, VALUE rReadOnly, VALUE rSnapshotRef, VALUE rTransportModes) {
  VixDiskLibConnectParams vConnectParams;
  VixDiskLibConnection   *pvConnection;
  VixError                vixError;
  VALUE                   tval;
  Bool                    vReadOnly;
  const char             *vSnapshotRef;
  const char             *vTransportModes;
    
  Check_Type(rConnectParams, T_HASH);
  
  memset(&vConnectParams, 0, sizeof(VixDiskLibConnectParams));  
  vConnectParams.vmxSpec            = GET_HASHED_STRING(rConnectParams, vmxSpec_sym, NULL);
  vConnectParams.serverName         = GET_HASHED_STRING(rConnectParams, serverName_sym, NULL);
  vConnectParams.port               = GET_HASHED_INT(rConnectParams, port_sym, 0);
  vConnectParams.credType           = GET_HASHED_INT(rConnectParams, credType_sym, 0);
  vConnectParams.creds.uid.userName = GET_HASHED_STRING(rConnectParams, userName_sym, NULL);
  vConnectParams.creds.uid.password = GET_HASHED_STRING(rConnectParams, password_sym, NULL);
    
	rb_log(log_debug, "%s.connectEx: vmxSpec    = %s", class_name, vConnectParams.vmxSpec);
	rb_log(log_debug, "%s.connectEx: credType   = %d", class_name, vConnectParams.credType);
    
  if ((pvConnection = malloc(sizeof(VixDiskLibConnection))) == NULL)    {
      rb_raise(rb_eNoMemError, "%s.connectEx: out of memory", class_name);
  }
  
  vReadOnly       = RTEST(rReadOnly)         ? TRUE : FALSE;
  vSnapshotRef    = (NIL_P(rSnapshotRef))    ? NULL : RSTRING_PTR(StringValue(rSnapshotRef));
  vTransportModes = (NIL_P(rTransportModes)) ? NULL : RSTRING_PTR(StringValue(rTransportModes));

	rb_log(LOGLEVEL_VERBOSE, "%s.connectEx: status=[starting] server=[%s], port=[%d], userid=[%s]", class_name, vConnectParams.serverName, vConnectParams.port, vConnectParams.creds.uid.userName);
    
  vixError = VixDiskLib_ConnectEx(&vConnectParams, vReadOnly, vSnapshotRef, vTransportModes, pvConnection);
  if (VIX_FAILED(vixError))    {
    free(pvConnection);
    vix_check(vixError, "connectEx");
  }
    
	rb_log(LOGLEVEL_VERBOSE, "%s.connectEx: status=[complete] connection=[0x%x]", class_name, *pvConnection);
    
  return Data_Wrap_Struct(rSelf, 0, vdl_free, pvConnection);
}


/*
 * The "create" class method.
 */
static VALUE
vdl_create(VALUE rSelf, VALUE rConnection, VALUE rPath, VALUE rCreateParams)   {
  VixDiskLibConnection    *pvConnection;
  char                    *vPath;
  VixDiskLibCreateParams  vCreateParams;
  VixError                vixError;
  VALUE                   tval;
    
  Check_Type(rCreateParams, T_HASH);
    
  vCreateParams.diskType     = GET_HASHED_INT(rCreateParams, diskType_sym,    VIXDISKLIB_DISK_MONOLITHIC_FLAT);
  vCreateParams.adapterType  = GET_HASHED_INT(rCreateParams, adapterType_sym, VIXDISKLIB_ADAPTER_UNKNOWN);
  vCreateParams.hwVersion    = GET_HASHED_INT(rCreateParams, hwVersion_sym,   VIXDISKLIB_HWVERSION_CURRENT);
  vCreateParams.capacity     = GET_HASHED_INT(rCreateParams, capacity_sym,    0);
    
  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
  vPath = RSTRING_PTR(StringValue(rPath));
    
	rb_log(log_debug, "%s.create: connection                = 0x%x", class_name, *pvConnection);
	rb_log(log_debug, "%s.create: path                      = %s",   class_name,  vPath);
	rb_log(log_debug, "%s.create: vCreateParams.diskType    = %d",   class_name,  vCreateParams.diskType);
	rb_log(log_debug, "%s.create: vCreateParams.adapterType = %d",   class_name,  vCreateParams.adapterType);
	rb_log(log_debug, "%s.create: vCreateParams.hwVersion   = %d",   class_name,  vCreateParams.hwVersion);
	rb_log(log_debug, "%s.create: vCreateParams.capacity    = %d",   class_name,  vCreateParams.capacity);

	rb_log(LOGLEVEL_VERBOSE, "%s.create: status=[starting] connection=[0x%x], path=[%s]", class_name, *pvConnection, vPath);
  vixError = VixDiskLib_Create(*pvConnection, vPath, &vCreateParams, NULL, NULL);
  vix_check(vixError, "create");
	rb_log(LOGLEVEL_VERBOSE, "%s.create: status=[complete] connection=[0x%x], path=[%s]", class_name, *pvConnection, vPath);
  return Qnil;
}

/*
 * The "createChild" class method.
 */
static VALUE
vdl_createChild(VALUE rSelf, VALUE rDiskHandle, VALUE rChildPath, VALUE rDiskType) {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                 vixError;
  char                    *vchildPath;
  VixDiskLibDiskType       vDiskType;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  vchildPath = RSTRING_PTR(StringValue(rChildPath));
  vDiskType  = NUM2UINT(rDiskType);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.createChild: status=[starting] diskHandle=[0x%x], childPath=[%s], diskType=[0x%x]", class_name, *pvDiskHandle, vchildPath, vDiskType);
  vixError = VixDiskLib_CreateChild(*pvDiskHandle, vchildPath, vDiskType, NULL, NULL);
  vix_check(vixError, "createChild");
	rb_log(LOGLEVEL_VERBOSE, "%s.createChild: status=[complete] diskHandle=[0x%x], childPath=[%s], diskType=[0x%x]", class_name, *pvDiskHandle, vchildPath, vDiskType);
  
  return Qnil;
}

/*
 * The "defragment" class method.
 */
static VALUE
vdl_defragment(VALUE rSelf, VALUE rDiskHandle)   {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                 vixError;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.defragment: status=[starting] diskHandle=[0x%x]", class_name, *pvDiskHandle);

  vixError = VixDiskLib_Defragment(*pvDiskHandle, NULL, NULL);
  vix_check(vixError, "defragment");
  
	rb_log(LOGLEVEL_VERBOSE, "%s.defragment: status=[complete] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  return Qnil;
}


/*
 * The "disconnect" class method.
 */
static VALUE
vdl_disconnect(VALUE rSelf, VALUE rConnection) {
  VixDiskLibConnection   *pvConnection;
  VixError                vixError;
    
  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.disconnect: status=[starting] connection=[0x%x]", class_name, *pvConnection);
    
  vixError = VixDiskLib_Disconnect(*pvConnection);
  vix_check(vixError, "disconnect");
  
	rb_log(LOGLEVEL_VERBOSE, "%s.disconnect: status=[complete] connection=[0x%x]", class_name, *pvConnection);
  return Qnil;
}

/*
 * The "exit" class method.
 */
static VALUE
vdl_exit(VALUE rSelf)    {
	rb_log(LOGLEVEL_VERBOSE, "%s.exit: status=[starting]", class_name);
  VixDiskLib_Exit();
	rb_log(LOGLEVEL_VERBOSE, "%s.exit: status=[complete]", class_name);
  return Qnil;
}

/*
 * The "getConnectParams" class method.
 */
static VALUE
vdl_getConnectParams(VALUE rSelf, VALUE rConnection) {
  VixDiskLibConnection    *pvConnection;
  VixError                 vixError;
  VixDiskLibConnectParams *pvConnectParams;
  VALUE                    rConnectParams;
  VALUE                    rCredType = Qnil;

  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);

  rb_log(LOGLEVEL_VERBOSE, "%s.getConnectParams: status=[starting] connection=[0x%x]", class_name, *pvConnection);
  vixError = VixDiskLib_GetConnectParams(*pvConnection, &pvConnectParams);
  vix_check(vixError, "getConnectParams");
  rb_log(LOGLEVEL_VERBOSE, "%s.getConnectParams: status=[complete] connection=[0x%x]", class_name, *pvConnection);

  rConnectParams = rb_hash_new();
  rb_hash_aset(rConnectParams, vmxSpec_sym,             (!pvConnectParams->vmxSpec) ? Qnil : rb_str_new2(pvConnectParams->vmxSpec));
  rb_hash_aset(rConnectParams, serverName_sym,          (!pvConnectParams->serverName) ? Qnil : rb_str_new2(pvConnectParams->serverName));

  switch (pvConnectParams->credType)   {
    case VIXDISKLIB_CRED_UID:
      rCredType = rb_const_get(cVixDiskLib_raw, rb_intern("VIXDISKLIB_CRED_UID"));
      break;
    case VIXDISKLIB_CRED_SESSIONID:
      rCredType = rb_const_get(cVixDiskLib_raw, rb_intern("VIXDISKLIB_CRED_SESSIONID"));
      break;
    case VIXDISKLIB_CRED_TICKETID:
      rCredType = rb_const_get(cVixDiskLib_raw, rb_intern("VIXDISKLIB_CRED_TICKETID"));
      break;
    case VIXDISKLIB_CRED_SSPI:
      rCredType = rb_const_get(cVixDiskLib_raw, rb_intern("VIXDISKLIB_CRED_SSPI"));
      break;
    case VIXDISKLIB_CRED_UNKNOWN:
      rCredType = rb_const_get(cVixDiskLib_raw, rb_intern("VIXDISKLIB_CRED_UNKNOWN"));
      break;
  }
  rb_hash_aset(rConnectParams, credType_sym,            rCredType);

  if (pvConnectParams->credType == VIXDISKLIB_CRED_UID) {
    rb_hash_aset(rConnectParams, userName_sym,             (!pvConnectParams->creds.uid.userName) ? Qnil : rb_str_new2(pvConnectParams->creds.uid.userName));
    rb_hash_aset(rConnectParams, password_sym,             (!pvConnectParams->creds.uid.password) ? Qnil : rb_str_new2(pvConnectParams->creds.uid.password));
  }

  if (pvConnectParams->credType == VIXDISKLIB_CRED_SESSIONID) {
    rb_hash_aset(rConnectParams, userName_sym,             (!pvConnectParams->creds.sessionId.userName) ? Qnil : rb_str_new2(pvConnectParams->creds.sessionId.userName));
    rb_hash_aset(rConnectParams, cookie_sym,               (!pvConnectParams->creds.sessionId.cookie)   ? Qnil : rb_str_new2(pvConnectParams->creds.sessionId.cookie));
    rb_hash_aset(rConnectParams, key_sym,                  (!pvConnectParams->creds.sessionId.key)      ? Qnil : rb_str_new2(pvConnectParams->creds.sessionId.key));
  }

  rb_hash_aset(rConnectParams, port_sym,                UINT2NUM(pvConnectParams->port));

  VixDiskLib_FreeConnectParams(pvConnectParams);
  return rConnectParams;
}

/*
 * The "getInfo" class method.
 */
static VALUE
vdl_getInfo(VALUE rSelf, VALUE rDiskHandle)   {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                vixError;
  VixDiskLibInfo          *pvDiskInfo;
  VALUE                   rInfoHash;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.getInfo: status=[starting] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  vixError = VixDiskLib_GetInfo(*pvDiskHandle, &pvDiskInfo);
  vix_check(vixError, "getInfo");
	rb_log(LOGLEVEL_VERBOSE, "%s.getInfo: status=[complete] diskHandle=[0x%x]", class_name, *pvDiskHandle);
    
  rInfoHash = rb_hash_new();
  rb_hash_aset(rInfoHash, biosGeoCylinders_sym,    UINT2NUM(pvDiskInfo->biosGeo.cylinders));
  rb_hash_aset(rInfoHash, biosGeoHeads_sym,        UINT2NUM(pvDiskInfo->biosGeo.heads));
  rb_hash_aset(rInfoHash, biosGeoSectors_sym,      UINT2NUM(pvDiskInfo->biosGeo.sectors));
  rb_hash_aset(rInfoHash, physGeoCylinders_sym,    UINT2NUM(pvDiskInfo->physGeo.cylinders));
  rb_hash_aset(rInfoHash, physGeoHeads_sym,        UINT2NUM(pvDiskInfo->physGeo.heads));
  rb_hash_aset(rInfoHash, physGeoSectors_sym,      UINT2NUM(pvDiskInfo->physGeo.sectors));
  rb_hash_aset(rInfoHash, capacity_sym,            ULL2NUM(pvDiskInfo->capacity));
  rb_hash_aset(rInfoHash, adapterType_sym,         INT2NUM(pvDiskInfo->adapterType));
  rb_hash_aset(rInfoHash, numLinks_sym,            INT2NUM(pvDiskInfo->numLinks));
  rb_hash_aset(rInfoHash, parentFileNameHint_sym,  (!pvDiskInfo->parentFileNameHint) ? Qnil : rb_str_new2(pvDiskInfo->parentFileNameHint));
    
  VixDiskLib_FreeInfo(pvDiskInfo);
  return rInfoHash;
}


/*
 * The "getMetadataKeys" class method.
 */
static VALUE
vdl_getMetadataKeys(VALUE rSelf, VALUE rDiskHandle) {
  VixDiskLibHandle       *pvDiskHandle;
  VixError                vixError;
  VALUE                   rArray;
  char                   *vKeyBuffer;
  char                   *pvKey;
  size_t                  vRequiredLen;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  
	rb_log(LOGLEVEL_VERBOSE, "%s.getMetadataKeys: status=[starting] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  vixError = VixDiskLib_GetMetadataKeys(*pvDiskHandle, NULL, 0, &vRequiredLen);
  if (vixError != VIX_OK && vixError != VIX_E_BUFFER_TOOSMALL) {
    vix_check(vixError, "getMetadataKeys");
  }
	rb_log(LOGLEVEL_VERBOSE, "%s.getMetadataKeys: status=[got_size] diskHandle=[0x%x], bufferSize=[%d]", class_name, *pvDiskHandle, vRequiredLen);
  
  if ((vKeyBuffer = malloc(vRequiredLen)) == NULL)	{
    rb_raise(rb_eNoMemError, "%s.getMetadataKeys: out of memory", class_name);
	}
	
  vixError = VixDiskLib_GetMetadataKeys(*pvDiskHandle, vKeyBuffer, vRequiredLen, NULL);
	if (VIX_FAILED(vixError))    {
    free(vKeyBuffer);
    vix_check(vixError, "getMetadataKeys");
  }
	rb_log(LOGLEVEL_VERBOSE, "%s.getMetadataKeys: status=[complete] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  
  rArray = rb_ary_new();

  pvKey = &vKeyBuffer[0];
  while (*pvKey) {
    rb_ary_push(rArray, rb_str_new2(pvKey));
    pvKey += (1 + strlen(pvKey));
  }

  free(vKeyBuffer);
  return rArray;
}


/*
 * The "getTransportMode" class method.
 */
static VALUE
vdl_getTransportMode(VALUE rSelf, VALUE rDiskHandle) {
  VixDiskLibHandle       *pvDiskHandle;
  const char             *vMode;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.getTransportMode: status=[starting] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  vMode = VixDiskLib_GetTransportMode(*pvDiskHandle);
	rb_log(LOGLEVEL_VERBOSE, "%s.getTransportMode: status=[complete] diskHandle=[0x%x] mode=[%s]", class_name, *pvDiskHandle, vMode);
  return rb_str_new2(vMode);  
}

/*
 * The "grow" class method.
 */
static VALUE
vdl_grow(VALUE rSelf, VALUE rConnection, VALUE rPath, VALUE rCapacity, VALUE rUpdateGeometry)   {
  VixDiskLibConnection    *pvConnection;
  VixError                 vixError;
  char                    *vPath;
  unsigned long long       vCapacity;  // VixDiskLibSectorType
  Bool                     vUpdateGeometry;

  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
  vPath           = RSTRING_PTR(StringValue(rPath));
  vCapacity       = NUM2ULL(rCapacity);
  vUpdateGeometry = RTEST(rUpdateGeometry) ? TRUE : FALSE;
    
	rb_log(LOGLEVEL_VERBOSE, "%s.grow: status=[starting] connection=[0x%x], path=[%s], capacity=[%llu], updateGeometry=[%s]", class_name, *pvConnection, vPath, vCapacity, vUpdateGeometry ? "true" : "false");
  vixError = VixDiskLib_Grow(*pvConnection, vPath, vCapacity, vUpdateGeometry, NULL, NULL);
  vix_check(vixError, "grow");
	rb_log(LOGLEVEL_VERBOSE, "%s.grow: status=[complete] connection=[0x%x], path=[%s], capacity=[%llu], updateGeometry=[%s]", class_name, *pvConnection, vPath, vCapacity, vUpdateGeometry ? "true" : "false");
  return Qnil;
}

/*
 * The "init" class method.
 */
static VALUE
vdl_init(VALUE rSelf, VALUE rLogInfo, VALUE rLogWarn, VALUE rLogError, VALUE rLibDir)	{
  char        *vLibDir;
  VixError    vixError;

  /*
	 * Set up the ruby logger instance used by this code to log messages.
	 */
	logger  = rb_gv_get("$vim_log");

  vLibDir  = (NIL_P(rLibDir)) ? NULL : RSTRING_PTR(StringValue(rLibDir));
    
  vdl_info_log_proc   = rLogInfo;
  vdl_warn_log_proc   = rLogWarn;
  vdl_error_log_proc  = rLogError;

	rb_log(LOGLEVEL_VERBOSE, "%s.init: status=[starting]", class_name);
  vixError = VixDiskLib_Init(VIXDISKLIB_VERSION_MAJOR, 
                             VIXDISKLIB_VERSION_MINOR,
                             vdl_log_info_proxy,
                             vdl_log_warn_proxy,
                             vdl_log_error_proxy,
                             vLibDir);
  vix_check(vixError, "init");
	rb_log(LOGLEVEL_VERBOSE, "%s.init: status=[complete]", class_name);
	
	return Qnil;
}

/*
 * The "initEx" class method.
 */
static VALUE
vdl_initEx(VALUE rSelf, VALUE rLogInfo, VALUE rLogWarn, VALUE rLogError, VALUE rLibDir, VALUE rConfigFile)	{
  char        *vLibDir;
  char        *vConfigFile;
  VixError     vixError;

  /*
	 * Set up the ruby logger instance used by this code to log messages.
	 */
	logger  = rb_gv_get("$vim_log");
	
  vLibDir     = (NIL_P(rLibDir))     ? NULL : RSTRING_PTR(StringValue(rLibDir));
  vConfigFile = (NIL_P(rConfigFile)) ? NULL : RSTRING_PTR(StringValue(rConfigFile));

  vdl_info_log_proc   = rLogInfo;
  vdl_warn_log_proc   = rLogWarn;
  vdl_error_log_proc  = rLogError;

	rb_log(LOGLEVEL_VERBOSE, "%s.initEx: status=[starting]", class_name);
  vixError = VixDiskLib_InitEx(VIXDISKLIB_VERSION_MAJOR, 
                               VIXDISKLIB_VERSION_MINOR,
                               vdl_log_info_proxy,
                               vdl_log_warn_proxy,
                               vdl_log_error_proxy,
                               vLibDir,
                               vConfigFile);
  vix_check(vixError, "initEx");
	rb_log(LOGLEVEL_VERBOSE, "%s.initEx: status=[complete]", class_name);
	return Qnil;
}


/*
 * The "listTransportModes" class method.
 */
static VALUE
vdl_listTransportModes(VALUE rSelf)    {
  const char  *vModes;
  
	rb_log(LOGLEVEL_VERBOSE, "%s.listTransportModes: status=[starting]", class_name);
  vModes = VixDiskLib_ListTransportModes();
	rb_log(LOGLEVEL_VERBOSE, "%s.listTransportModes: status=[complete] modes=[%s]", class_name, vModes);
	
  return rb_str_new2(vModes);  
}

/*
 * The "open" class method.
 */
static VALUE
vdl_open(VALUE rSelf, VALUE rConnection, VALUE rPath, VALUE rFlags) {
  VixDiskLibConnection   *pvConnection;
  VixDiskLibHandle       *pvDiskHandle;
  VixError                vixError;
  char                   *vPath;
  uint32                  vFlags;
    
  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
  vPath  = RSTRING_PTR(StringValue(rPath));
  vFlags = NUM2UINT(rFlags);
    
  if ((pvDiskHandle = malloc(sizeof(VixDiskLibHandle))) == NULL)    {
    rb_raise(rb_eNoMemError, "%s.open: out of memory", class_name);
  }

	rb_log(LOGLEVEL_VERBOSE, "%s.open: status=[starting] connection=[0x%x], path=[%s], flags=[0x%x]", class_name, *pvConnection, vPath, vFlags);
  vixError = VixDiskLib_Open(*pvConnection, vPath, vFlags, pvDiskHandle);

#ifdef HAVE_OPENSSL_EVP_H
  /*
   * VixDiskLib_Open calls EVP_cleanup(). This clears the cipher table, causing
   * subsequent calls to the Ruby OpenSSL binding to fail.
   *
   * As a workaround, the following call reloads the table.
   */
  OpenSSL_add_all_algorithms();
#endif
    
  if (VIX_FAILED(vixError))    {
    free(pvDiskHandle);
    vix_check(vixError, "open");
  }

	rb_log(LOGLEVEL_VERBOSE, "%s.open: status=[complete] connection=[0x%x], path=[%s], flags=[0x%x], diskHandle=[0x%x]", class_name, *pvConnection, vPath, vFlags, *pvDiskHandle);

  return Data_Wrap_Struct(rSelf, 0, vdl_free, pvDiskHandle);
}

/*
 * The "read" class method.
 */
static VALUE
vdl_read(VALUE rSelf, VALUE rDiskHandle, VALUE rStartSector, VALUE rNumSectors) {
  VALUE                   rReadBuffer;
  char                    *vReadBuffer;
  VixDiskLibHandle        *pvDiskHandle;
  VixError                vixError;
  unsigned long long      vStartSector; // Sector
  unsigned long long      vNumSectors;  // Sectors
  unsigned long long      buflen;       // read length in bytes
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  vStartSector = NUM2ULL(rStartSector);
  vNumSectors = NUM2ULL(rNumSectors);
    
  /*
	 * Allocate a Ruby string buffer.
	 */
  buflen = vNumSectors * VIXDISKLIB_SECTOR_SIZE;
  rReadBuffer = rb_str_buf_new(buflen);
  rb_str_set_len(rReadBuffer, buflen);
  vReadBuffer = RSTRING_PTR(rReadBuffer);
	
	rb_log(LOGLEVEL_VERBOSE, "%s.read: status=[starting] handle=[0x%x], startSector=[%llu], numSectors=[%llu]", class_name, *pvDiskHandle, vStartSector, vNumSectors);
	
	vixError = VixDiskLib_Read(*pvDiskHandle, vStartSector, vNumSectors, (uint8 *)vReadBuffer);
  if (VIX_FAILED(vixError))    {
    vix_check(vixError, "read");
  }
    
	rb_log(LOGLEVEL_VERBOSE, "%s.read: status=[complete] handle=[0x%x], bytes=[%llu]", class_name, *pvDiskHandle, buflen);

	return rReadBuffer;
}

/*
 * The "readMetadata" class method.
 */
static VALUE
vdl_readMetadata(VALUE rSelf, VALUE rDiskHandle, VALUE rKey) {
  VixDiskLibHandle       *pvDiskHandle;
  VixError                vixError;
  VALUE                   rValue;
  char                   *vValue;
  size_t                  vRequiredLen;
  char                   *vKey;
    
  Check_Type(rKey, T_STRING);
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  
  vKey  = RSTRING_PTR(StringValue(rKey));
  
  vixError = VixDiskLib_ReadMetadata(*pvDiskHandle, vKey, NULL, 0, &vRequiredLen);
  if (vixError != VIX_OK && vixError != VIX_E_BUFFER_TOOSMALL) {
    vix_check(vixError, "readMetadata");
  }

  /*
	 * Allocate a Ruby string buffer.
	 */
  rValue = rb_str_buf_new(vRequiredLen);
  vValue = RSTRING_PTR(rValue);
	
  vixError = VixDiskLib_ReadMetadata(*pvDiskHandle, vKey, vValue, vRequiredLen, NULL);
	if (VIX_FAILED(vixError))    {
    vix_check(vixError, "readMetadata");
  }

  rb_str_set_len(rValue, strlen(vValue));
  return rValue;
}

/*
 * The "rename" class method.
 */
static VALUE
vdl_rename(VALUE rSelf, VALUE rSourceFileName, VALUE rTargetFileName)   {
  VixError                 vixError;
  char                    *vSourceFileName;
  char                    *vTargetFileName;

  vSourceFileName = RSTRING_PTR(StringValue(rSourceFileName));
  vTargetFileName = RSTRING_PTR(StringValue(rTargetFileName));
    
	rb_log(LOGLEVEL_VERBOSE, "%s.rename: status=[starting] source=[%s], target=[%s]", class_name, vSourceFileName, vTargetFileName);
  vixError = VixDiskLib_Rename(vSourceFileName, vTargetFileName);
  vix_check(vixError, "rename");
	rb_log(LOGLEVEL_VERBOSE, "%s.rename: status=[complete] source=[%s], target=[%s]", class_name, vSourceFileName, vTargetFileName);
	
  return Qnil;
}

/*
 * The "reparent" class method.
 */
static VALUE
vdl_reparent(VALUE rSelf, VALUE rConnection, VALUE rPath, VALUE rParentHint)   {
  VixDiskLibConnection    *pvConnection;
  VixError                 vixError;
  char                    *vPath;
  char                    *vParentHint;

  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
  vPath       = RSTRING_PTR(StringValue(rPath));
  vParentHint = RSTRING_PTR(StringValue(rParentHint));

  rb_log(LOGLEVEL_VERBOSE, "%s.reparent: status=[starting] connection=[0x%x], path=[%s], parentHint=[%s]", class_name, *pvConnection, vPath, vParentHint);
  vixError = VixDiskLib_Reparent(*pvConnection, vPath, vParentHint);
  vix_check(vixError, "reparent");
  rb_log(LOGLEVEL_VERBOSE, "%s.reparent: status=[complete] connection=[0x%x], path=[%s], parentHint=[%s]", class_name, *pvConnection, vPath, vParentHint);

  return Qnil;
}

/*
 * The "shrink" class method.
 */
static VALUE
vdl_shrink(VALUE self, VALUE rDiskHandle)   {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                 vixError;
    
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
    
	rb_log(LOGLEVEL_VERBOSE, "%s.shrink: status=[starting] diskHandle=[0x%x]", class_name, *pvDiskHandle);
  vixError = VixDiskLib_Shrink(*pvDiskHandle, NULL, NULL);
  vix_check(vixError, "shrink");
	rb_log(LOGLEVEL_VERBOSE, "%s.shrink: status=[complete] diskHandle=[0x%x]", class_name, *pvDiskHandle);
	
  return Qnil;
}


/*
 * The "spaceNeededForClone" class method.
 */
static VALUE
vdl_spaceNeededForClone(VALUE rSelf, VALUE rDiskHandle, VALUE rDiskType)   {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                 vixError;
  VixDiskLibDiskType       vDiskType;
  uint64                   vSpaceNeeded;
  
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  vDiskType  = NUM2UINT(rDiskType);

	rb_log(LOGLEVEL_VERBOSE, "%s.spaceNeededForClone: status=[starting] diskHandle=[0x%x], diskType=[%d]", class_name, *pvDiskHandle, vDiskType);
  vixError = VixDiskLib_SpaceNeededForClone(*pvDiskHandle, vDiskType, &vSpaceNeeded);
  vix_check(vixError, "spaceNeededForClone");
	rb_log(LOGLEVEL_VERBOSE, "%s.spaceNeededForClone: status=[complete] diskHandle=[0x%x], diskType=[%d], spaceNeeded=[%llu]", class_name, *pvDiskHandle, vDiskType, vSpaceNeeded);
	
  return ULL2NUM(vSpaceNeeded);
}

/*
 * The "unlink" class method.
 */
static VALUE
vdl_unlink(VALUE rSelf, VALUE rConnection, VALUE rPath) {
  VixDiskLibConnection    *pvConnection;
  VixError                 vixError;
  char                    *vPath;
    
  Data_Get_Struct(rConnection, VixDiskLibConnection, pvConnection);
  vPath  = RSTRING_PTR(StringValue(rPath));
    
	rb_log(LOGLEVEL_VERBOSE, "%s.unlink: status=[starting] connection=[0x%x], path=[%s]", class_name, *pvConnection, vPath);
  vixError = VixDiskLib_Unlink(*pvConnection, vPath);
  vix_check(vixError, "unlink");
	rb_log(LOGLEVEL_VERBOSE, "%s.unlink: status=[complete] connection=[0x%x], path=[%s]", class_name, *pvConnection, vPath);
	
  return Qnil;
}

/*
 * The "verbose" class method.
 */
static VALUE
vdl_verbose_getter(VALUE self)  {
  return verbose ? Qtrue : Qfalse;
}

/*
 * The "verbose=" class method.
 */
static VALUE
vdl_verbose_setter(VALUE self, VALUE rBool)  {
  verbose = RTEST(rBool) ? TRUE : FALSE;
  return verbose ? Qtrue : Qfalse;
}



/*
 * The "write" class method.
 */
static VALUE
vdl_write(VALUE rSelf, VALUE rDiskHandle, VALUE rStartSector, VALUE rNumSectors, VALUE rWriteBuffer) {
  VixDiskLibHandle        *pvDiskHandle;
  VixError                vixError;
  unsigned long long      vStartSector; // Sector
  unsigned long long      vNumSectors;  // Sectors
  unsigned long long      len;         // write length in bytes
  
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  vStartSector = NUM2ULL(rStartSector);
  vNumSectors  = NUM2ULL(rNumSectors);
    
  len = vNumSectors * VIXDISKLIB_SECTOR_SIZE;
  if ( len > (unsigned long long)RSTRING_LEN(StringValue(rWriteBuffer)))   {
    rb_raise(rb_eStandardError, "%s.write: attempt to write more data than buffer contains", class_name);
  }
  
	rb_log(LOGLEVEL_VERBOSE, "%s.write: status=[starting] handle=[0x%x], startSector=[%llu], numSectors=[%llu]", class_name, *pvDiskHandle, vStartSector, vNumSectors);
  vixError = VixDiskLib_Write(*pvDiskHandle, vStartSector, vNumSectors, (uint8 *)RSTRING_PTR(StringValue(rWriteBuffer)));
  vix_check(vixError, "write");
	rb_log(LOGLEVEL_VERBOSE, "%s.write: status=[complete] handle=[0x%x], startSector=[%llu], numSectors=[%llu]", class_name, *pvDiskHandle, vStartSector, vNumSectors);
	
  return Qnil;
}


/*
 * The "writeMetadata" class method.
 */
static VALUE
vdl_writeMetadata(VALUE rSelf, VALUE rDiskHandle, VALUE rKey, VALUE rValue) {
  VixDiskLibHandle       *pvDiskHandle;
  VixError                vixError;
  const char             *vKey;
  const char             *vValue;
    
  Check_Type(rKey,   T_STRING);
  Check_Type(rValue, T_STRING);
  Data_Get_Struct(rDiskHandle, VixDiskLibHandle, pvDiskHandle);
  
  vKey   = RSTRING_PTR(StringValue(rKey));
  vValue = RSTRING_PTR(StringValue(rValue));
  
	rb_log(LOGLEVEL_VERBOSE, "%s.writeMetadata: status=[starting] handle=[0x%x], key=[%s], value=[%s]", class_name, *pvDiskHandle, vKey, vValue);
  vixError = VixDiskLib_WriteMetadata(*pvDiskHandle, vKey, vValue);
  vix_check(vixError, "writeMetadata");
	rb_log(LOGLEVEL_VERBOSE, "%s.writeMetadata: status=[complete] handle=[0x%x], key=[%s], value=[%s]", class_name, *pvDiskHandle, vKey, vValue);
	
  return Qnil;
}


/****************************************************************************/


/*
 * Initialize the class.
 */
void Init_VixDiskLib_raw()	{
  
	/*
	 * Define the exception class.
	 */
  rb_eVixDiskLibError = rb_define_class(exception_name, rb_eRuntimeError);
  
	/*
	 * Define the class.
	 */
	cVixDiskLib_raw = rb_define_class(class_name, rb_cObject);
	
	/*
	 * Define class methods.
	 */
 	rb_define_singleton_method(cVixDiskLib_raw, "attach",  	           vdl_attach,               2);
  rb_define_singleton_method(cVixDiskLib_raw, "checkRepair",         vdl_checkRepair,          3);
  rb_define_singleton_method(cVixDiskLib_raw, "cleanup", 	           vdl_cleanup,              1);
	rb_define_singleton_method(cVixDiskLib_raw, "clone",	             vdl_clone,                6);
	rb_define_singleton_method(cVixDiskLib_raw, "close",	             vdl_close,                1);
	rb_define_singleton_method(cVixDiskLib_raw, "combine",	           vdl_combine,              3);
	rb_define_singleton_method(cVixDiskLib_raw, "connect",	           vdl_connect,              1);
	rb_define_singleton_method(cVixDiskLib_raw, "connectEx",           vdl_connectEx,            4);
	rb_define_singleton_method(cVixDiskLib_raw, "create",  	           vdl_create,               3);
	rb_define_singleton_method(cVixDiskLib_raw, "createChild",  	     vdl_createChild,          3);
	rb_define_singleton_method(cVixDiskLib_raw, "defragment",  	       vdl_defragment,           1);
	rb_define_singleton_method(cVixDiskLib_raw, "disconnect", 	       vdl_disconnect,           1);
	rb_define_singleton_method(cVixDiskLib_raw, "exit",	               vdl_exit,                 0);
	rb_define_singleton_method(cVixDiskLib_raw, "getConnectParams",	   vdl_getConnectParams,     1);
	rb_define_singleton_method(cVixDiskLib_raw, "getInfo",	           vdl_getInfo,              1);
	rb_define_singleton_method(cVixDiskLib_raw, "getMetadataKeys",     vdl_getMetadataKeys,      1);
	rb_define_singleton_method(cVixDiskLib_raw, "getTransportMode",    vdl_getTransportMode,     1);
	rb_define_singleton_method(cVixDiskLib_raw, "grow",  	             vdl_grow,                 4);
	rb_define_singleton_method(cVixDiskLib_raw, "init",	               vdl_init,                 4);
  rb_define_singleton_method(cVixDiskLib_raw, "initEx",              vdl_initEx,               5);
	rb_define_singleton_method(cVixDiskLib_raw, "listTransportModes",  vdl_listTransportModes,   0);
	rb_define_singleton_method(cVixDiskLib_raw, "open",	               vdl_open,                 3);
	rb_define_singleton_method(cVixDiskLib_raw, "read",	               vdl_read,                 3);
	rb_define_singleton_method(cVixDiskLib_raw, "readMetadata",        vdl_readMetadata,         2);
	rb_define_singleton_method(cVixDiskLib_raw, "rename",  	           vdl_rename,               2);
	rb_define_singleton_method(cVixDiskLib_raw, "reparent",  	         vdl_reparent,             3);
	rb_define_singleton_method(cVixDiskLib_raw, "shrink",  	           vdl_shrink,               1);
	rb_define_singleton_method(cVixDiskLib_raw, "spaceNeededForClone", vdl_spaceNeededForClone,  2);
	rb_define_singleton_method(cVixDiskLib_raw, "unlink",  	           vdl_unlink,               2);
	rb_define_singleton_method(cVixDiskLib_raw, "verbose",             vdl_verbose_getter,       0);
	rb_define_singleton_method(cVixDiskLib_raw, "verbose=",            vdl_verbose_setter,       1);
	rb_define_singleton_method(cVixDiskLib_raw, "write",	             vdl_write,                4);
	rb_define_singleton_method(cVixDiskLib_raw, "writeMetadata",       vdl_writeMetadata,        3);

	/*
	 * Create constants in this class based on values defined in vixDiskLib.h
	 */
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_FLAG_OPEN_UNBUFFERED);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_FLAG_OPEN_SINGLE_LINK);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_FLAG_OPEN_READ_ONLY);
    
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_UID);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_SESSIONID);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_TICKETID);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_SSPI);                    // Windows only - use current thread credentials.
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_UNKNOWN);
    
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_SECTOR_SIZE);
    
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_ADAPTER_IDE);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_ADAPTER_SCSI_BUSLOGIC);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_ADAPTER_SCSI_LSILOGIC);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_ADAPTER_UNKNOWN);
    
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_MONOLITHIC_SPARSE);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_MONOLITHIC_FLAT);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_SPLIT_SPARSE);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_SPLIT_FLAT);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_VMFS_FLAT);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_STREAM_OPTIMIZED);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_VMFS_THIN);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_VMFS_SPARSE);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_DISK_UNKNOWN);
    
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_HWVERSION_WORKSTATION_4);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_HWVERSION_WORKSTATION_5);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_HWVERSION_ESX30);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_HWVERSION_WORKSTATION_6);
  INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_HWVERSION_CURRENT);
	
	/*
   * Initialize symbol keys for connection parameters.
   */
  vmxSpec_sym             = STR2SYM("vmxSpec");               // :vmxSpec
  serverName_sym          = STR2SYM("serverName");            // :serverName
  credType_sym            = STR2SYM("credType");              // :credType
                                                              // when credType == VIXDISKLIB_CRED_UID
  userName_sym            = STR2SYM("userName");              //   :userName
  password_sym            = STR2SYM("password");              //   :password
                                                              // when credType == VIXDISKLIB_CRED_SESSIONID
  cookie_sym              = STR2SYM("cookie");                //   :cookie
  key_sym                 = STR2SYM("key");                   //   :key
  port_sym                = STR2SYM("port");                  // :port
    
  /*
   * Initialize symbol keys for VixDiskLibInfo.
   */
  biosGeoCylinders_sym    = STR2SYM("biosGeoCylinders");      // :biosGeoCylinders
  biosGeoHeads_sym        = STR2SYM("biosGeoHeads");          // :biosGeoHeads
  biosGeoSectors_sym      = STR2SYM("biosGeoSectors");        // :biosGeoSectors
  physGeoCylinders_sym    = STR2SYM("physGeoCylinders");      // :physGeoCylinders
  physGeoHeads_sym        = STR2SYM("physGeoHeads");          // :physGeoHeads
  physGeoSectors_sym      = STR2SYM("physGeoSectors");        // :physGeoSectors
  capacity_sym            = STR2SYM("capacity");              // :capacity
  adapterType_sym         = STR2SYM("adapterType");           // :adapterType
  numLinks_sym            = STR2SYM("numLinks");              // :numLinks
  parentFileNameHint_sym  = STR2SYM("parentFileNameHint");    // :parentFileNameHint
    
  /*
   * Initialize symbol keys for VixDiskLibCreateParams.
   */
  diskType_sym			= STR2SYM("diskType");              // :diskType
  hwVersion_sym			= STR2SYM("hwVersion");             // :hwVersion

	/*
	 * Log levels.
	 */
	log_info				= rb_intern("info");
	log_warn				= rb_intern("warn");
	log_error				= rb_intern("error");
	log_debug				= rb_intern("debug");
     
   /*
    * External ruby procs for logging,
    */
  vdl_info_log_proc  = Qnil;
  vdl_warn_log_proc  = Qnil;
  vdl_error_log_proc = Qnil;
  
  /*
	 * Set up the ruby logger instance used by this code to log messages.
	 */
	logger  = rb_gv_get("$vim_log");
  verbose = FALSE;
	
}
