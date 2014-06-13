
#include	<stdlib.h>
#include	<slp.h>
#include	<stdio.h>
#include	<string.h>

struct SRV_URL_CB_INFO	{
	SLPError	callbackerr;
	int			num_url;
	char		*srv_urls[100];
};

SLPBoolean MySLPSrvURLCallback( SLPHandle hslp,
	const char* srvurl,
	unsigned short lifetime,
	SLPError errcode,
	void* cookie )
{
	struct SRV_URL_CB_INFO *cbinfop;
	
	cbinfop = (struct SRV_URL_CB_INFO *)cookie;
	
	if(errcode == SLP_OK)	{
		// printf("Service URL     = %s\n", srvurl);
		// printf("Service Timeout = %i\n", lifetime);
		
		cbinfop->srv_urls[cbinfop->num_url++] = strdup(srvurl);
		cbinfop->callbackerr = SLP_OK;
	}
	else if(errcode == SLP_LAST_CALL)	{
		// printf("Service URL     = %s\n", srvurl);
		// printf("Service Timeout = %i\n", lifetime);
		cbinfop->callbackerr = SLP_OK;
	}
	else	{
		cbinfop->callbackerr = errcode;
	}

	/* return SLP_TRUE because we want to be called again */
	/* if more services were found                        */

	return SLP_TRUE;
}

SLPBoolean myAttrCallback(SLPHandle hslp,
	const char* attrlist,
	SLPError errcode,
	void* cookie )
{
	if(errcode == SLP_OK)	{
		printf("%s\n", attrlist);
	}

	return SLP_FALSE;
}

int
main(int argc, char **argv)
{
	SLPError	slprv;
	SLPHandle	slph;
	struct SRV_URL_CB_INFO cbinfo;
	
	slprv = SLPOpen(NULL, SLP_FALSE, &slph);
	if(slprv != SLP_OK)	{
		printf("Error opening slp handle %i\n", slprv);
		exit(1);
	}
	
	cbinfo.num_url = 0;
	
	slprv = SLPFindSrvs( slph,
		"service:wbem",
		0,                    /* use configured scopes */
		0,                    /* no attr filter        */
		MySLPSrvURLCallback,
		&cbinfo );

	if((slprv != SLP_OK) || (cbinfo.callbackerr != SLP_OK))	{
		printf("SLPFindSrvs Error: %i\n", slprv);
		exit(1);
	}
	else	{
		int i;
		printf("SLPFindSrvs discovered %d servers:\n", cbinfo.num_url);
		for(i = 0; i < cbinfo.num_url; i++)	{
			printf("\t%s\n", cbinfo.srv_urls[i]);
			slprv = SLPFindAttrs(slph,
				cbinfo.srv_urls[i],
				"", /* attributes */
				"", /* use configured scopes */
				myAttrCallback,
				NULL);
			if(slprv != SLP_OK)	{
				printf("errorcode: %i\n", slprv);
			}
		}
	}
	
	SLPClose(slph);
}
