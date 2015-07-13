
#include <stdio.h>
#include <unistd.h>
#include <mk4.h>
#include <ruby.h>

const char *MK_FENTRY   = "fentry[fpath:S,ftype:I,fsize:I,ftags:B,fdata:B]";
const char *MK_HASHVW   = "sec[_H:I,_R:I]";

const char *SAMP_FILE   = "/lib/fs/MetakitFS/test/init.rb";

const char *
get_exepath(char *argv[])
{
	static char exe_path[PATH_MAX];
#	if defined (WIN)
		GetModuleFileName(NULL, exe_path, MPATH_MAX);
#   elif defined (LINUX)
		char proc_path[MPATH_MAX];
		int len;
		
		sprintf(proc_path, "/proc/%d/exe", getpid());
		if ((len = readlink(proc_path, exe_path, sizeof(exe_path)-1)) != -1)	{
			exe_path[len] = '\0';
		}
		else	{
			perror(proc_path);
			exit(1);
		}
#	else
        char *p;
        
        if ((p = getenv("_")) != NULL)    {
            strcpy(exe_path, p);
        }
        else    {
            strcpy(exe_path, argv[0]);
        }
#   endif
	return(exe_path);
}

main(int argc, char *argv[])
{
    int             findex;
    long            flen;
    const t4_byte   *buf_ptr;
    c4_Row          findRow;
    c4_Row          row;
    
    c4_StringProp   pPath("fpath");
    c4_IntProp      pType("ftype");
    c4_IntProp      pSize("fsize");
    c4_BytesProp    pData("fdata");
    
    c4_Storage storage (get_exepath(argv), true);    
    printf("Descriptiom: %s\n", storage.Description());
    
    c4_View vData   = storage.GetAs(MK_FENTRY);
    c4_View vSec    = storage.GetAs(MK_HASHVW);
    c4_View vFentry = vData.Hash(vSec, true);
        
    pPath.Set(findRow, SAMP_FILE);
    findex = vFentry.Find(findRow, 0);
    printf("%s file index = %d\n", SAMP_FILE, findex);
    
    if (findex < 0) {
        printf("File not found: %s\n", SAMP_FILE);
        exit(1);
    }
    
    row = vFentry.GetAt(findex);
    printf("File: %s, Size: %d\n", pPath.Get(row), pSize.Get(row));
    
    c4_Bytes file_data = pData.Get(row);
    flen = file_data.Size();
    printf("c4_Bytes.Size() = %ld\n", flen);
    
    buf_ptr = file_data.Contents();
    
    ruby_init(); 
    ruby_init_loadpath();
        
    rb_funcall(rb_mKernel, rb_intern("eval"), 3,
               rb_str_new((const char *)buf_ptr, flen),
               rb_const_get(rb_mKernel, rb_intern("TOPLEVEL_BINDING")),
               rb_str_new2("myFile.rb"));
    
    ruby_finalize();
    exit(0);
}

