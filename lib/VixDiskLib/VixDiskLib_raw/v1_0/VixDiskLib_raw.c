/*
 * Ruby module bridge to VixDiskLib.
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
#include <openssl/evp.h>    // needed for VixDiskLib_Open bug workaround

#include "ruby.h"
#undef EXTERN
#undef NORETURN
#include "vixDiskLib.h"

#define VIXDISKLIB_VERSION_MAJOR 1
#define VIXDISKLIB_VERSION_MINOR 0

/*
 * Read a string value from a hash using the given key.
 */
#define GET_HASHED_STRING(hash, key, dflt) \
         ((tval = rb_hash_aref(hash, key)) == Qnil ? dflt : RSTRING(StringValue(tval))->ptr)
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

static char *class_name = "VixDiskLib_raw";

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
rb_log(VALUE level, char *fmt, ...)	{
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
vix_check(VixError err, char *method) {
    char *msg, msg_buf[1024];
    
    if (VIX_FAILED(err))    {
        msg = VixDiskLib_GetErrorText(err, NULL);
        (void)strncpy(msg_buf, msg, sizeof(msg_buf)-1);
        msg_buf[sizeof(msg_buf) - 1] = '\0';
        VixDiskLib_FreeErrorText(msg);
        rb_raise(rb_eStandardError, "%s.%s: %s", class_name, method , msg_buf);
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
    VALUE   log_proc;
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

/*
 * The "init" class method.
 */
static VALUE
vdl_init(VALUE self, VALUE logInfo, VALUE logWarn, VALUE logError, VALUE libDir)	{
    char        *lDir;
    VixError    vixError;

	/*
	 * Set up the ruby logger instance used by this code to log messages.
	 */
	logger = rb_gv_get("$vim_log");
    
    if (NIL_P(libDir))  {
        lDir = NULL;
    }
    else    {
        lDir = RSTRING(StringValue(libDir))->ptr;
    }

    vdl_info_log_proc   = logInfo;
    vdl_warn_log_proc   = logWarn;
    vdl_error_log_proc  = logError;

    vixError = VixDiskLib_Init(VIXDISKLIB_VERSION_MAJOR, 
                               VIXDISKLIB_VERSION_MINOR,
                               vdl_log_info_proxy,
                               vdl_log_warn_proxy,
                               vdl_log_error_proxy,
                               lDir);
    vix_check(vixError, "init");
	return Qnil;
}

/*
 * The "exit" class method.
 */
static VALUE
vdl_exit(VALUE self)    {
    VixDiskLib_Exit();
    return Qnil;
}

/*
 * Symbol hash keys for connection parameters.
 */
static VALUE vmxSpec_sym;
static VALUE serverName_sym;
static VALUE credType_sym;
static VALUE userName_sym;
static VALUE password_sym;
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

static void
vdl_free(void *p)	{
	free(p);
}

/*
 * The "connect" class method.
 */
static VALUE
vdl_connect(VALUE self, VALUE connectParms) {
    VixDiskLibConnectParams conParms;
    VixDiskLibConnection    *connection;
    VixError                vixError;
    VALUE                   tval;
    
    Check_Type(connectParms, T_HASH);
    
    conParms.vmxSpec            = GET_HASHED_STRING(connectParms, vmxSpec_sym, NULL);
    conParms.serverName         = GET_HASHED_STRING(connectParms, serverName_sym, NULL);
    conParms.port               = GET_HASHED_INT(connectParms, port_sym, 0);
    conParms.credType           = GET_HASHED_INT(connectParms, credType_sym, 0);
    conParms.creds.uid.userName = GET_HASHED_STRING(connectParms, userName_sym, NULL);
    conParms.creds.uid.password = GET_HASHED_STRING(connectParms, password_sym, NULL);
    
	rb_log(log_info,  "%s.connect: serverName = %s", class_name, conParms.serverName);
	rb_log(log_debug, "%s.connect: vmxSpec    = %s", class_name, conParms.vmxSpec);
	rb_log(log_debug, "%s.connect: port       = %d", class_name, conParms.port);
	rb_log(log_debug, "%s.connect: credType   = %d", class_name, conParms.credType);
	rb_log(log_debug, "%s.connect: userName   = %s", class_name, conParms.creds.uid.userName);
	rb_log(log_debug, "%s.connect: password   = %s", class_name, conParms.creds.uid.password);
    
    if ((connection = malloc(sizeof(VixDiskLibConnection))) == NULL)    {
        rb_raise(rb_eNoMemError, "%s.connect: out of memory", class_name);
    }
    
    vixError = VixDiskLib_Connect(&conParms, connection);
    if (VIX_FAILED(vixError))    {
        free(connection);
        vix_check(vixError, "connect");
    }
    
	rb_log(log_info, "%s.connect: connection = 0x%x", class_name, *connection);
    
    return Data_Wrap_Struct(self, 0, vdl_free, connection);
}

/*
 * The "disconnect" class method.
 */
static VALUE
vdl_disconnect(VALUE self, VALUE connection) {
    VixDiskLibConnection    *vdcp;
    VixError                vixError;
    
    Data_Get_Struct(connection, VixDiskLibConnection, vdcp);
    
	rb_log(log_info, "%s.disconnect: connection = 0x%x", class_name, *vdcp);
    
    vixError = VixDiskLib_Disconnect(*vdcp);
    vix_check(vixError, "disconnect");
    return Qnil;
}

/*
 * The "open" class method.
 */
static VALUE
vdl_open(VALUE self, VALUE connection, VALUE path, VALUE flags) {
    VixDiskLibConnection    *vdcp;
    VixDiskLibHandle        *vdhp;
    VixError                vixError;
    char                    *path_p;
    uint32                  oflags;
    
    Data_Get_Struct(connection, VixDiskLibConnection, vdcp);
    path_p  = RSTRING(StringValue(path))->ptr;
    oflags = NUM2UINT(flags);
    
	rb_log(log_info, "%s.open: connection = 0x%x", class_name, *vdcp);
	rb_log(log_info, "%s.open: path       = %s", class_name, path_p);
	rb_log(log_info, "%s.open: flags      = 0x%x", class_name, oflags);

    if ((vdhp = malloc(sizeof(VixDiskLibHandle))) == NULL)    {
        rb_raise(rb_eNoMemError, "%s.open: out of memory", class_name);
    }

    vixError = VixDiskLib_Open(*vdcp, path_p, oflags, vdhp);
    
    /*
     * VixDiskLib_Open calls EVP_cleanup(). This clears the cipher table, causing
     * subsequent calls to the Ruby OpenSSL binding to fail.
     *
     * As a workaround, the following call reloads the table.
     */
    OpenSSL_add_all_algorithms();
    
    if (VIX_FAILED(vixError))    {
        free(vdhp);
        vix_check(vixError, "open");
    }

	rb_log(log_debug, "%s.open: diskHandle = 0x%x", class_name, *vdhp);

    return Data_Wrap_Struct(self, 0, vdl_free, vdhp);
}

/*
 * The "close" class method.
 */
static VALUE
vdl_close(VALUE self, VALUE diskHandle) {
    VixDiskLibHandle        *vdhp;
    VixError                vixError;
    
    Data_Get_Struct(diskHandle, VixDiskLibHandle, vdhp);

	rb_log(log_info, "%s.close: diskHandle = 0x%x", class_name, *vdhp);

    vixError = VixDiskLib_Close(*vdhp);
    vix_check(vixError, "close");
    return Qnil;
}

/*
 * The "read" class method.
 */
static VALUE
vdl_read(VALUE self, VALUE diskHandle, VALUE startSector, VALUE numSectors) {
    VALUE                   rb;
    VixDiskLibHandle        *vdhp;
    VixError                vixError;
    unsigned long long      sSector;    // Sector
    unsigned long long      nSectors;   // Sectors
    unsigned long long      rlen;       // read length in bytes
    char                    *readBuffer;
    
    Data_Get_Struct(diskHandle, VixDiskLibHandle, vdhp);
    sSector = NUM2ULL(startSector);
    nSectors = NUM2ULL(numSectors);
    
    /*
	 * Allocate a temp read buffer.
	 */
    rlen = nSectors * VIXDISKLIB_SECTOR_SIZE;
	if ((readBuffer = malloc(rlen)) == NULL)	{
		rb_raise(rb_eNoMemError,
			"%s.read - could not allocate memory for read buffer",
            class_name);
	}
	
	vixError = VixDiskLib_Read(*vdhp, sSector, nSectors, readBuffer);
    if (VIX_FAILED(vixError))    {
        free(readBuffer);
        vix_check(vixError, "read");
    }
    
    /*
	 * Create a Ruby string and initialize it with the
	 * contents of the temp buffer.
	 */
	rb = rb_str_new(readBuffer, rlen);
	// we no longer need the temp buffer.
	free(readBuffer);
	// return the ruby string.
	return rb;
}

/*
 * The "write" class method.
 */
static VALUE
vdl_write(VALUE self, VALUE diskHandle, VALUE startSector, VALUE numSectors, VALUE writeBuffer) {
    VixDiskLibHandle        *vdhp;
    VixError                vixError;
    unsigned long long      sSector;    // Sector
    unsigned long long      nSectors;   // Sectors
    unsigned long long      wLen;       // write length in bytes
    
    Data_Get_Struct(diskHandle, VixDiskLibHandle, vdhp);
    sSector = NUM2ULL(startSector);
    nSectors = NUM2ULL(numSectors);
    writeBuffer = StringValue(writeBuffer);
    

    wLen = nSectors * VIXDISKLIB_SECTOR_SIZE;
    if ( wLen > RSTRING_LEN(writeBuffer))   {
        rb_raise(rb_eStandardError, "%s.write: attempt to write more data than buffer contains", class_name);
    }
    
    vixError = VixDiskLib_Write(*vdhp, sSector, nSectors, RSTRING_PTR(writeBuffer));
    vix_check(vixError, "write");
    return Qnil;
}

/*
 * The "getInfo" clss method.
 */
static VALUE
vdl_getInfo(VALUE self, VALUE diskHandle)   {
    VixDiskLibHandle        *vdhp;
    VixError                vixError;
    VixDiskLibInfo          *dinfo;
    VALUE                   infoHash;
    
    Data_Get_Struct(diskHandle, VixDiskLibHandle, vdhp);
    
	rb_log(log_debug, "%s.getInfo: diskHandle = 0x%x", class_name, *vdhp);

    vixError = VixDiskLib_GetInfo(*vdhp, &dinfo);
    vix_check(vixError, "getInfo");
    
    infoHash = rb_hash_new();
    rb_hash_aset(infoHash, biosGeoCylinders_sym,    UINT2NUM(dinfo->biosGeo.cylinders));
    rb_hash_aset(infoHash, biosGeoHeads_sym,        UINT2NUM(dinfo->biosGeo.heads));
    rb_hash_aset(infoHash, biosGeoSectors_sym,      UINT2NUM(dinfo->biosGeo.sectors));
    rb_hash_aset(infoHash, physGeoCylinders_sym,    UINT2NUM(dinfo->physGeo.cylinders));
    rb_hash_aset(infoHash, physGeoHeads_sym,        UINT2NUM(dinfo->physGeo.heads));
    rb_hash_aset(infoHash, physGeoSectors_sym,      UINT2NUM(dinfo->physGeo.sectors));
    rb_hash_aset(infoHash, capacity_sym,            ULL2NUM(dinfo->capacity));
    rb_hash_aset(infoHash, adapterType_sym,         INT2NUM(dinfo->adapterType));
    rb_hash_aset(infoHash, numLinks_sym,            INT2NUM(dinfo->numLinks));
    if (!dinfo->parentFileNameHint) {
        rb_hash_aset(infoHash, parentFileNameHint_sym,  Qnil);
    }
    else    {
        rb_hash_aset(infoHash, parentFileNameHint_sym,  rb_str_new2(dinfo->parentFileNameHint));
    }
    
    VixDiskLib_FreeInfo(dinfo);
    return infoHash;
}

/*
 * The "clone" clss method.
 */
static VALUE
vdl_dclone(VALUE self, VALUE dstConnection, VALUE dstPath, 
                      VALUE srcConnection, VALUE srcPath,
                      VALUE createParms, VALUE overwrite)   {
                          
    VixDiskLibConnection    *d_vdcp, *s_vdcp;
    char                    *d_path, *s_path;
    VixDiskLibCreateParams  cParms;
    VixError                vixError;
    VALUE                   tval;
    
    Check_Type(createParms, T_HASH);
    
    cParms.diskType     = GET_HASHED_INT(createParms, diskType_sym, VIXDISKLIB_DISK_MONOLITHIC_FLAT);
    cParms.adapterType  = GET_HASHED_INT(createParms, adapterType_sym, VIXDISKLIB_ADAPTER_UNKNOWN);
    cParms.hwVersion    = GET_HASHED_INT(createParms, hwVersion_sym, VIXDISKLIB_HWVERSION_CURRENT);
    cParms.capacity     = GET_HASHED_INT(createParms, capacity_sym, 0);
    
    Data_Get_Struct(dstConnection, VixDiskLibConnection, d_vdcp);
    Data_Get_Struct(srcConnection, VixDiskLibConnection, s_vdcp);
    
    d_path = RSTRING(StringValue(dstPath))->ptr;
    s_path = RSTRING(StringValue(srcPath))->ptr;
    
	rb_log(log_debug, "%s.dclone: dst connection     = 0x%x", class_name, *d_vdcp);
	rb_log(log_debug, "%s.dclone: dst path           = %s", class_name, d_path);
	rb_log(log_debug, "%s.dclone: src connection     = 0x%x", class_name, *s_vdcp);
	rb_log(log_debug, "%s.dclone: src path           = %s", class_name, s_path);
	rb_log(log_debug, "%s.dclone: overwrite          = %d", class_name, RTEST(overwrite));
	rb_log(log_debug, "%s.dclone: cParms.diskType    = %d", class_name, cParms.diskType);
	rb_log(log_debug, "%s.dclone: cParms.adapterType = %d", class_name, cParms.adapterType);
	rb_log(log_debug, "%s.dclone: cParms.hwVersion   = %d", class_name, cParms.hwVersion);
	rb_log(log_debug, "%s.dclone: cParms.capacity    = %d", class_name, cParms.capacity);

    vixError = VixDiskLib_Clone(*d_vdcp, d_path, *s_vdcp, s_path, &cParms, NULL, NULL, RTEST(overwrite));
    vix_check(vixError, "dclone");
    return Qnil;
}

VALUE	cVixDiskLib_raw;

/*
 * Initialize the class.
 */
void Init_VixDiskLib_raw()	{
	/*
	 * Define the class.
	 */
	cVixDiskLib_raw = rb_define_class(class_name, rb_cObject);
	
	/*
	 * Define class methods.
	 */
	rb_define_singleton_method(cVixDiskLib_raw, "init",	        vdl_init,       4);
	rb_define_singleton_method(cVixDiskLib_raw, "exit",	        vdl_exit,       0);
	
	rb_define_singleton_method(cVixDiskLib_raw, "connect",	    vdl_connect,    1);
	rb_define_singleton_method(cVixDiskLib_raw, "disconnect",	vdl_disconnect, 1);
	
	rb_define_singleton_method(cVixDiskLib_raw, "open",	        vdl_open,       3);
	rb_define_singleton_method(cVixDiskLib_raw, "close",	    vdl_close,      1);
	
	rb_define_singleton_method(cVixDiskLib_raw, "read",	        vdl_read,       3);
	rb_define_singleton_method(cVixDiskLib_raw, "write",	    vdl_write,      4);
	rb_define_singleton_method(cVixDiskLib_raw, "getInfo",	    vdl_getInfo,    1);
	rb_define_singleton_method(cVixDiskLib_raw, "dclone",	    vdl_dclone,     6);
	
	/*
	 * Create constants in this class based on values defined in vixDiskLib.h
	 */
    INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_FLAG_OPEN_UNBUFFERED);
    INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_FLAG_OPEN_SINGLE_LINK);
    INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_FLAG_OPEN_READ_ONLY);
    
    INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_UID);
    INTDEF2CONST(cVixDiskLib_raw, VIXDISKLIB_CRED_SESSIONID);
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
    userName_sym            = STR2SYM("userName");              // :userName
    password_sym            = STR2SYM("password");              // :password
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
}
