/*
* Ruby module bridge to libslp 1.2.1.
*/

#include <stdarg.h>
#include <stdio.h>

#include "ruby.h"
#include "slp.h"

#define	TRUE	1
#define	FALSE	!TRUE

#define LOGLEVEL_VERBOSE  (verbose ? log_info : log_debug)

static char		*class_name     = "SlpLib_raw";
static char		*exception_name = "SlpLibError_raw";
static VALUE	cSlpLib_raw;
static VALUE	rb_eSlpLibError;
static int		verbose;

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
 * Check the slplib return code and raise a Ruby exception,
 * with descriptive text, if there was an error.
 */
static void
slp_check(SLPError err, char *method) {
	if (err != SLP_OK)    {
		rb_raise(rb_eSlpLibError, "%s.%s (errcode=%d)", class_name, method, err);
	}
}

static void
slp_free(void *p)	{
	free(p);
}

struct SRV_URL_CB_INFO	{
	SLPError	callbackerr;
	VALUE		rRetVal;
};

static SLPBoolean
slpSrvURLCallback( SLPHandle hslp,
					const char* srvurl,
					unsigned short lifetime,
					SLPError errcode,
					void* cookie )
{
	struct SRV_URL_CB_INFO *cbinfop;
	
	cbinfop = (struct SRV_URL_CB_INFO *)cookie;
	Check_Type(cbinfop->rRetVal, T_ARRAY);
	
	if(errcode == SLP_OK)	{
		rb_log(LOGLEVEL_VERBOSE, "%s.slpSrvURLCallback: (SLP_OK) srvurl=[%s], lifetime=[%i]",
				class_name, srvurl, lifetime);
		rb_ary_push(cbinfop->rRetVal, rb_str_new2(srvurl));
		cbinfop->callbackerr = SLP_OK;
	}
	else if(errcode == SLP_LAST_CALL)	{
		rb_log(LOGLEVEL_VERBOSE, "%s.slpSrvURLCallback: (SLP_LAST_CALL) srvurl=[%s], lifetime=[%i]",
				class_name, srvurl, lifetime);
		cbinfop->callbackerr = SLP_OK;
	}
	else	{
		rb_log(LOGLEVEL_VERBOSE, "%s.slpSrvURLCallback: (SLP_ERROR) errcode=[%d]", class_name, errcode);
		cbinfop->callbackerr = errcode;
	}
	return SLP_TRUE;
}

static SLPBoolean
attrCallback(SLPHandle hslp,
				const char* attrlist,
				SLPError errcode,
				void* cookie )
{
	struct SRV_URL_CB_INFO *cbinfop;
	
	cbinfop = (struct SRV_URL_CB_INFO *)cookie;
	
	if(errcode == SLP_OK)	{
		rb_log(LOGLEVEL_VERBOSE, "%s.attrCallback: (SLP_OK) srvurl=[%s]", class_name, attrlist);
		cbinfop->rRetVal = rb_str_new2(attrlist);
		cbinfop->callbackerr = SLP_OK;
	}
	else	{
		rb_log(LOGLEVEL_VERBOSE, "%s.attrCallback: (SLP_ERROR) errcode=[%d]", class_name, errcode);
		cbinfop->callbackerr = errcode;
	}

	return SLP_FALSE;
}

/*******************************************************/
/***    Implementation of Ruby Method Bindings   *******/
/*******************************************************/

static VALUE
slp_open(VALUE rSelf, VALUE rLang, VALUE rIsasync) {
	char		*lang;
	SLPBoolean	isasync;
	SLPError	slpError;
	SLPHandle	*slphp;
	
	lang	= (rLang == Qnil ? NULL : RSTRING_PTR(StringValue(rLang)));
	isasync	= (rIsasync == Qtrue ? SLP_TRUE : SLP_FALSE);

	if ((slphp = malloc(sizeof(SLPHandle))) == NULL)    {
		rb_raise(rb_eNoMemError, "%s.open: out of memory", class_name);
	}

	rb_log(LOGLEVEL_VERBOSE, "%s.open: (call) lang=[%s], isasync=[%d]", class_name, lang, isasync);
	
	slpError = SLPOpen(lang, isasync, slphp);
	
	if (slpError != SLP_OK)    {
		free(slphp);
		slp_check(slpError, "open");
	}
	
	rb_log(LOGLEVEL_VERBOSE, "%s.open: (return) handle=[0x%x]", class_name, *slphp);
	
	return Data_Wrap_Struct(rSelf, 0, slp_free, slphp);
}

static VALUE
slp_close(VALUE rSelf, VALUE rHandle) {
	SLPHandle	*slphp;
	
	Data_Get_Struct(rHandle, SLPHandle, slphp);
	rb_log(LOGLEVEL_VERBOSE, "%s.close: (call) handle=[0x%x]", class_name, *slphp);
	SLPClose(*slphp);
	rb_log(LOGLEVEL_VERBOSE, "%s.close: (return) handle=[0x%x]", class_name, *slphp);
	
	return Qnil;
}

static VALUE
slp_findSrvs(VALUE rSelf, VALUE rHandle, VALUE rSrvtype, VALUE rScopelist, VALUE rFilter) {
	SLPHandle				*slphp;
	const char				*srvtype;
	const char				*scopelist;
	const char				*filter;
	SLPError				slpError;
	struct SRV_URL_CB_INFO	cbinfo;
	
	Data_Get_Struct(rHandle, SLPHandle, slphp);
	Check_Type(rSrvtype, T_STRING);
	srvtype		= RSTRING_PTR(StringValue(rSrvtype));
	scopelist	= (rScopelist	== Qnil ? NULL : RSTRING_PTR(StringValue(rScopelist)));
	filter		= (rFilter		== Qnil ? NULL : RSTRING_PTR(StringValue(rFilter)));
	
	cbinfo.rRetVal = rb_ary_new();
	
	rb_log(LOGLEVEL_VERBOSE, "%s.findsrvs: (call) handle=[0x%x], srvtype=[%s], scopelist=[%s], filter=[%s]",
			class_name, *slphp, srvtype, scopelist, filter);
	
	slpError = SLPFindSrvs(*slphp, srvtype, scopelist, filter, slpSrvURLCallback, &cbinfo);
	
	rb_log(LOGLEVEL_VERBOSE, "%s.findsrvs: (return) handle=[0x%x], srvtype=[%s], scopelist=[%s], filter=[%s]",
			class_name, *slphp, srvtype, scopelist, filter);
			
	slp_check(slpError, "findsrvs");
	slp_check(cbinfo.callbackerr, "findsrvs");

	return cbinfo.rRetVal;
}

static VALUE
slp_findAttrs(VALUE rSelf, VALUE rHandle, VALUE rSrvurl, VALUE rScopelist, VALUE rAttrids) {
	SLPHandle				*slphp;
	const char				*srvurl;
	const char				*scopelist;
	const char				*attrids;
	SLPError				slpError;
	struct SRV_URL_CB_INFO	cbinfo;
	
	Data_Get_Struct(rHandle, SLPHandle, slphp);
	Check_Type(rSrvurl, T_STRING);
	srvurl		= RSTRING_PTR(StringValue(rSrvurl));
	scopelist	= (rScopelist	== Qnil ? NULL : RSTRING_PTR(StringValue(rScopelist)));
	attrids		= (rAttrids		== Qnil ? NULL : RSTRING_PTR(StringValue(rAttrids)));
	
	rb_log(LOGLEVEL_VERBOSE, "%s.findattrs: (call) handle=[0x%x], srvurl=[%s], scopelist=[%s], attrids=[%s]",
			class_name, *slphp, srvurl, scopelist, attrids);
	
	slpError = SLPFindAttrs(*slphp, srvurl, scopelist, attrids, attrCallback, &cbinfo);
	
	rb_log(LOGLEVEL_VERBOSE, "%s.findattrs: (return) handle=[0x%x], srvurl=[%s], scopelist=[%s], attrids=[%s]",
			class_name, *slphp, srvurl, scopelist, attrids);
			
	slp_check(slpError, "findsrvs");
	slp_check(cbinfo.callbackerr, "findsrvs");

	return cbinfo.rRetVal;
}

/*
 * Symbol hash keys for SLPSrvURL.
 */
static VALUE pcSrvType_sym;
static VALUE pcHost_sym;
static VALUE iPort_sym;
static VALUE pcNetFamily_sym;
static VALUE pcSrvPart_sym;

static VALUE
slp_ParseSrvURL(VALUE rSelf, VALUE rSrvurl)	{
	const char	*srvurl;
	SLPSrvURL	*parsedurl;
	SLPError	slpError;
	VALUE		rRetVal;
	
	Check_Type(rSrvurl, T_STRING);
	srvurl = RSTRING_PTR(StringValue(rSrvurl));
	
	slpError = SLPParseSrvURL(srvurl, &parsedurl);
	slp_check(slpError, "ParseSrvURL");
	
	rRetVal = rb_hash_new();
	
	rb_hash_aset(rRetVal, pcSrvType_sym,	rb_str_new2(parsedurl->s_pcSrvType));
	rb_hash_aset(rRetVal, pcHost_sym,		rb_str_new2(parsedurl->s_pcHost));
	rb_hash_aset(rRetVal, iPort_sym,		INT2NUM(parsedurl->s_iPort));
	rb_hash_aset(rRetVal, pcNetFamily_sym,	rb_str_new2(parsedurl->s_pcNetFamily));
	rb_hash_aset(rRetVal, pcSrvPart_sym,	rb_str_new2(parsedurl->s_pcSrvPart));
	SLPFree(parsedurl);
	
	return rRetVal;
}

#define STR2SYM(str)    ID2SYM(rb_intern((str)))

/*
 * Initialize the class.
 */
void Init_SlpLib_raw()	{

	/*
	 * Define the exception class.
	 */
	rb_eSlpLibError = rb_define_class(exception_name, rb_eRuntimeError);

	/*
	 * Define the class.
	 */
	cSlpLib_raw = rb_define_class(class_name, rb_cObject);

	/*
	 * Define class methods.
	 */
	rb_define_singleton_method(cSlpLib_raw, "open",			slp_open,			2);
	rb_define_singleton_method(cSlpLib_raw, "close",		slp_close,			1);
	rb_define_singleton_method(cSlpLib_raw, "findSrvs",		slp_findSrvs,		4);
	rb_define_singleton_method(cSlpLib_raw, "findAttrs",	slp_findAttrs,		4);
	rb_define_singleton_method(cSlpLib_raw, "parseSrvURL",	slp_ParseSrvURL,	1);
	
	/*
 	 * Initialize symbol keys for VixDiskLibInfo.
	 */
	pcSrvType_sym	= STR2SYM("pcSrvType");		// :pcSrvType
	pcHost_sym		= STR2SYM("pcHost");		// :pcHost
	iPort_sym		= STR2SYM("iPort");			// :iPort
	pcNetFamily_sym	= STR2SYM("pcNetFamily");	// :pcNetFamily
	pcSrvPart_sym	= STR2SYM("pcSrvPart");		// :pcSrvPart
	
	/*
	 * Log levels.
	 */
	log_info	= rb_intern("info");
	log_warn	= rb_intern("warn");
	log_error	= rb_intern("error");
	log_debug	= rb_intern("debug");
	
	/*
	 * Set up the ruby logger instance used by this code to log messages.
	 */
	logger  = rb_gv_get("$log");
	verbose = FALSE;

}
