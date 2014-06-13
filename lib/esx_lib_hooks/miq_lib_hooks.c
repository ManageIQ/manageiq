#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <dlfcn.h>
#include <stdio.h>
#include <errno.h>
#include <execinfo.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <paths.h>
#include <sys/wait.h>

#define LOG 	if (miq_loglevel >= 1) fprintf
#define LOG2	if (miq_loglevel >= 2) fprintf
#define LOG3	if (miq_loglevel >= 3) fprintf
#define LOG4	if (miq_loglevel >= 4) fprintf

#ifndef MIQ_LOGLEVEL
#	define MIQ_LOGLEVEL	0
#endif

#ifndef MIQ_STACKSYMBOLS
#	define	MIQ_STACKSYMBOLS 1
#endif

#ifndef MIQ_TARGET_PROC
#	define	MIQ_TARGET_PROC	"vmware-hostd"
#endif

/*
 *	0 - No log.
 *	1 - Log errors and calls to exec().
 *	2 - also log calls to open().
 *	3 - add stack trace information.
 *	4 - also log calls to close() and dup().
 */
static int miq_loglevel = MIQ_LOGLEVEL;

/*
 * When 1, print symbols in stack trace.
 * When 0, just print addresses.
 */
static int miq_stacksymbols = MIQ_STACKSYMBOLS;

/*
 * When non-NULL, the name of the command that will be monitored.
 * When NULL, all processes are monitored.
 */
static char *miq_target_proc = MIQ_TARGET_PROC;

static const char *miq_open_log = "/tmp/miq_open-%d.log";
static const char *proc_file    = "/proc/%d/cmdline";

static void *libc_handle;

#define __set_errno(val) (errno = (val))

static void *
get_libc_sym(const char *sym)
{
	void *r_sym;
	char *error;
	
	if (!libc_handle)	{
		libc_handle = dlopen("/lib/tls/libc.so.6", RTLD_LAZY);

		if (!libc_handle)	{
			fprintf(stderr, "%s\n", dlerror());
			return NULL;
		}
	}
	r_sym = dlsym(libc_handle, sym);
	if ((error = dlerror()) != NULL)	{
		fprintf(stderr, "get_libc_sym(%s): %s\n", sym, error);
		return NULL;
	}
	return r_sym;
}

static int
real_execve(const char *path, char *const argv[], char *const envp[])
{
	static int (*r_execve)(const char *path, char *const argv[], char *const envp[]) = NULL;
	
	if (!r_execve)	{
		if ((r_execve = get_libc_sym("execve")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_execve(path, argv, envp);
}

static int
real_open(const char *file, int oflag, int mode)
{
	static int (*r_open)(const char *file, int oflag, ...) = NULL;
	
	if (!r_open)	{
		if ((r_open = get_libc_sym("open")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_open(file, oflag, mode);
}

static int
real_open64(const char *file, int oflag, int mode)
{
	static int (*r_open64)(const char *file, int oflag, ...) = NULL;
	
	if (!r_open64)	{
		if ((r_open64 = get_libc_sym("open64")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_open64(file, oflag, mode);
}

static int
real_creat(const char *file, mode_t mode)
{
	static int (*r_creat)(const char *file, mode_t mode) = NULL;
	
	if (!r_creat)	{
		if ((r_creat = get_libc_sym("creat")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_creat(file, mode);
}

static int
real_creat64(const char *file, mode_t mode)
{
	static int (*r_creat64)(const char *file, mode_t mode) = NULL;
	
	if (!r_creat64)	{
		if ((r_creat64 = get_libc_sym("creat64")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_creat64(file, mode);
}

static int
real_close(int fd)
{
	static int (*r_close)(int fd) = NULL;

	if (!r_close)	{
		if ((r_close = dlsym(libc_handle, "close")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_close(fd);
}

static int
real_dup(int fd)
{
	static int (*r_dup)(int fd) = NULL;

	if (!r_dup)	{
		if ((r_dup = dlsym(libc_handle, "dup")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_dup(fd);
}

static int
real_dup2(int fd, int fd2)
{
	static int (*r_dup2)(int fd, int fd2) = NULL;

	if (!r_dup2)	{
		if ((r_dup2 = dlsym(libc_handle, "dup2")) == NULL)	{
			__set_errno(ENOSYS);
			return -1;
		}
	}
	return r_dup2(fd, fd2);
}

static int
ext_is(const char *str, const char *ext)
{
	const char *sp, *ep;
	int i;
	
	i = strlen(str) - strlen(ext);
	
	if (i < 0)	return 0;
	for (sp = &str[i], ep = ext; *ep; sp++, ep++)	{
		if (*sp != *ep)	return 0;
	}
	return 1;
}

static int
basename_is(const char *str, const char *cmp)
{
	const char *sp, *cp;
	int i;
	
	i = strlen(str) - strlen(cmp);
	
	if (i > 0 && str[i-1] != '/')	return 0;
	for (sp = &str[i], cp = cmp; *cp; sp++, cp++)	{
		if (*sp != *cp)	return 0;
	}
	return 1;
}

static pid_t	mypid;
static int		log_fd;
static FILE		*log_fp;
static char		miq_cmdline[256];

static void
miq_init(void)
{
	char file_name[128];
	char *evp;
	static int initialized = 0;
	int clfd;
	
	if (initialized)	return;
	
	if ((evp = getenv("MIQ_LOGLEVEL"))		!= NULL)	miq_loglevel = atoi(evp);
	if ((evp = getenv("MIQ_STACKSYMBOLS"))	!= NULL)	miq_stacksymbols = atoi(evp);
	if ((evp = getenv("MIQ_TARGET_PROC"))	!= NULL)	{
		if (strcmp(evp, "NULL") == 0)	{
			miq_target_proc = NULL;
		}
		else	{
			miq_target_proc = evp;
		}
	}
	
	mypid = getpid();
	sprintf(file_name, proc_file, mypid);
	if ((clfd = real_open(file_name, O_RDONLY, 0)) < 0)	{
		perror("miq_init:");
		fprintf(stderr, "miq_init: can't open %s\n", file_name);
	}
	if (read(clfd, miq_cmdline, 256) < 0)	{
		perror("miq_init:");
		fprintf(stderr, "miq_init: can't read %s\n", file_name);
	}

	if (miq_target_proc)	{
		if (basename_is(miq_cmdline, miq_target_proc))	{
			unsetenv("LD_PRELOAD");
		}
		else	{
			miq_loglevel = 0;
		}
	}
	
	initialized = 1;
}

static FILE *
open_log()
{
	miq_init();
	
	if (!miq_loglevel)	{
		log_fd = -2;
		return NULL;
		/* NOTREACHED */
	}

	if (!log_fp)	{
		char file_name[128];
		
		sprintf(file_name, miq_open_log, mypid);
		if ((log_fd = real_open(file_name, O_WRONLY|O_CREAT, 0755)) < 0)	{
			perror("open_log:");
			fprintf(stderr, "open_log: can't open log file %s\n", file_name);
			return NULL;
		}
		if ((log_fp = fdopen(log_fd, "w")) == NULL)	{
			perror("open_log:");
			fprintf(stderr, "open_log: can't open stream to file %s\n", file_name);
			return NULL;
		}
		setvbuf(log_fp, NULL, _IONBF, 0);
		LOG(log_fp, "open_log: log file open, pid = %d.\n", mypid);
		LOG(log_fp, "open_log: log fd: %d\n", log_fd);
		LOG(log_fp, "Command line: %s\n", miq_cmdline);
	}
	return(log_fp);
}

static void
log_trace()
{
	FILE *logfp;
	void *trace[256];
	int i, trace_size = 0;
		
	if (!miq_loglevel)	{
		return;
		/* NOTREACHED */
	}
	
	logfp = open_log();

	trace_size = backtrace(trace, 256);
	
	LOG3(logfp, "Stack trace:\n");

	if (miq_stacksymbols)	{
		char **messages;
		
		messages = backtrace_symbols(trace, trace_size);
		for (i=0; i<trace_size; ++i)	{
			LOG3(logfp, "\t%s\n", messages[i]);
		}
	}
	else	{
		for (i=0; i<trace_size; ++i)	{
			LOG3(logfp, "\t0x%x\n", (unsigned int)trace[i]);
		}
	}
}

static const char *csokpath = "/bin/sh";
static char *csokargv[] = { "sh", "-c", NULL, 0 };
static char *csokformat = "/opt/miq/bin/miq-cmd -r policycheckvm %s";

static int
check_start_ok(const char *vmxfile)
{
	pid_t pid, w;
	int status;
	FILE *logfp;
	
	logfp = open_log();
	
	LOG(logfp, "check_start_ok: %s\n", vmxfile);
	pid = fork();
	if (pid < 0)	{
		LOG(logfp, "check_start_ok: fork failed: %d\n", errno);
		return 0;
	}
	if (pid == 0)	{
		char cmdbuf[256];
		sprintf(cmdbuf, csokformat, (char *)vmxfile);
		csokargv[2] = cmdbuf;
		if (miq_loglevel)	{
			char **avp;
			LOG(logfp, "check_start_ok: exec'ing %s\n", csokpath);
			for (avp = csokargv; *avp; avp++)	{
				LOG(logfp, "\t%s\n", *avp);
			}
		}
		if (real_execve(csokpath, csokargv, __environ) < 0)	{
			LOG(logfp, "check_start_ok: exec of %s failed: %d\n", csokpath, errno);
			return 0;
		}
	}
	else	{
		do	{
			w = waitpid(pid, &status, 0);
			if (w < 0)	{
				LOG(logfp, "check_start_ok: waitpid failed: %d\n", errno);
				return 0;
			}
			if (WIFEXITED(status))	{
				int rv = WEXITSTATUS(status);
				LOG(logfp, "check_start_ok: %s returned: %d\n", csokpath, rv);
				LOG(logfp, "check_start_ok: returning: %d\n", !rv);
				return !rv;
			}
			if (WIFSIGNALED(status))	{
				LOG(logfp, "check_start_ok: killed by signal: %d\n", WTERMSIG(status));
				return 0;
			}
		} while(1);
	}
	return 1;
}

int
execve(const char *path, char *const argv[], char *const envp[])
{
	int rv;
	char *vmxfile = NULL;
	char *const *avp;
	FILE *logfp;
	
	logfp = open_log();
	LOG(logfp, "\n*** miq_execve ***\n");
	LOG(logfp, "miq_execve, path: %s\n", path);
	LOG(logfp, "miq_execve, args:\n");
	for (avp = argv; *avp; avp++)	{
		LOG(logfp, "\t%s\n", *avp);
	}
	if (basename_is(path, "vmkload_app"))	{
		LOG(logfp, "*** Starting VM: ");
		for (avp = argv; *avp; avp++)	{
			if (ext_is(*avp, ".vmx"))	{
				LOG(logfp, "%s\n", *avp);
				vmxfile = *avp;
				break;
			}
		}
		if (!check_start_ok(vmxfile))	{
			LOG(logfp, "*** Not starting VM, Permission denied\n");
			__set_errno(EACCES);
			return -1;
		}
	}
	LOG(logfp, "miq_execve, calling execvp\n");
	rv = real_execve(path, argv, envp);
	LOG(logfp, "miq_execve, execvp returned: %d\n", rv);
	return rv;
}

int
execv(const char *path, char *const argv[])
{
	FILE *logfp;
	
	logfp = open_log();
	LOG(logfp, "\n*** miq_execv ***\n");
	return execve(path, argv, __environ);
}

#define INITIAL_ARGV_MAX 1024

int
execl(const char *path, const char *arg, ...)
{
	size_t argv_max = INITIAL_ARGV_MAX;
	const char *initial_argv[INITIAL_ARGV_MAX];
	const char **argv = initial_argv;
	va_list args;
	FILE *logfp;
	
	logfp = open_log();
	LOG(logfp, "\n*** miq_execl ***\n");
	
	argv[0] = arg;
	
	va_start(args, arg);
	unsigned int i = 0;
	while (argv[i++] != NULL)	{
	    if (i == argv_max)	{
	        argv_max *= 2;
	        const char **nptr = realloc(argv == initial_argv ? NULL : argv,
	                                     argv_max * sizeof (const char *));
	        if (nptr == NULL)	{
	            if (argv != initial_argv)	{
	            	free (argv);
				}
	            return -1;
	        }
	        if (argv == initial_argv)	{
	        	memcpy(nptr, argv, i * sizeof (const char *));
			}
	
	        argv = nptr;
	    }
	
	    argv[i] = va_arg(args, const char *);
	}
	va_end (args);
	
	int ret = execve(path, (char *const *) argv, __environ);
	if (argv != initial_argv)	{
		free (argv);
	}
	
	return ret;
}

int
execle(const char *path, const char *arg, ...)
{
	size_t argv_max = INITIAL_ARGV_MAX;
	const char *initial_argv[INITIAL_ARGV_MAX];
	const char **argv = initial_argv;
	va_list args;
	argv[0] = arg;
	FILE *logfp;
	
	logfp = open_log();
	LOG(logfp, "\n*** miq_execle ***\n");
	
	va_start(args, arg);
	unsigned int i = 0;
	while (argv[i++] != NULL)	{
	    if (i == argv_max)	{
	        argv_max *= 2;
	        const char **nptr = realloc(argv == initial_argv ? NULL : argv,
	                                     argv_max * sizeof (const char *));
	        if (nptr == NULL)	{
	            if (argv != initial_argv)	{
	            	free (argv);
				}
	            return -1;
	        }
	        if (argv == initial_argv)	{
	        	memcpy(nptr, argv, i * sizeof (const char *));
			}
	
	        argv = nptr;
	    }
	    argv[i] = va_arg(args, const char *);
	}
	
	const char *const *envp = va_arg(args, const char *const *);
	va_end (args);
	
	int ret = execve(path, (char *const *) argv, (char *const *) envp);
	if (argv != initial_argv)	{
		free (argv);
	}
	return ret;
}

static char **
allocate_scripts_argv (const char *file, char *const argv[])
{
	int argc = 0;
	while (argv[argc++]);
	
	char **new_argv = (char **) malloc ((argc + 1) * sizeof (char *));
	if (new_argv != NULL)	{
	    new_argv[0] = (char *) _PATH_BSHELL;
	    new_argv[1] = (char *) file;
	    while (argc > 1)	{
	        new_argv[argc] = argv[argc - 1];
	        --argc;
	    }
	}	
	return new_argv;
}

extern char *strchrnul(const char *__s, int __c);

int
execvp(const char *file, char *const argv[])
{
	FILE *logfp;
	
	logfp = open_log();
	LOG(logfp, "\n*** miq_execvp ***\n");
	
	if (*file == '\0')	{
	    __set_errno(ENOENT);
	    return -1;
	}
	
	char **script_argv = NULL;
	
	if (strchr (file, '/') != NULL)	{
	    execve(file, argv, __environ);
	
	    if (errno == ENOEXEC)	{
	        script_argv = allocate_scripts_argv(file, argv);
	        if (script_argv != NULL)	{
	            execve(script_argv[0], script_argv, __environ);
	            free(script_argv);
	        }
	    }
	}
	else	{
		char *path = getenv ("PATH");
	  	char *path_malloc = NULL;
	  	if (path == NULL)	{
	    	size_t len = confstr(_CS_PATH, (char *) NULL, 0);
	      	path = (char *) malloc(1 + len);
	      	if (path == NULL)	{
				return -1;
		  	}
	      	path[0] = ':';
	      	(void) confstr(_CS_PATH, path + 1, len);
	      	path_malloc = path;
	  	}
	
	  	size_t len = strlen(file) + 1;
	  	size_t pathlen = strlen(path);
	  	char *name = malloc(pathlen + len + 1);
	  	if (name == NULL)	{
	      	free(path_malloc);
	      	return -1;
	  	}
	  	name = (char *) memcpy (name + pathlen + 1, file, len);
	  	*--name = '/';
	
	  	bool got_eacces = false;
	  	char *p = path;
	  	do	{
	      	char *startp;
	
	      	path = p;
	      	p = strchrnul(path, ':');
	
	      	if (p == path)	{
	        	startp = name + 1;
		  	}
	      	else	{
	        	startp = (char *) memcpy(name - (p - path), path, p - path);
		  	}
	
			execve(startp, argv, __environ);
	
	    	if (errno == ENOEXEC)	{
				if (script_argv == NULL)	{
				    script_argv = allocate_scripts_argv(startp, argv);
				    if (script_argv == NULL)	{
				        got_eacces = false;
				        break;
				    }
				}
				execve(script_argv[0], script_argv, __environ);
	    	}
	
	    	switch (errno)	{
	      		case EACCES:
	
	      		case ENOENT:
	      		case ESTALE:
	      		case ENOTDIR:
	
	      		case ENODEV:
	      		case ETIMEDOUT:
	        		break;
	
	      		default:
	            	return -1;
	        }
	    }	while (*p++ != '\0');
	
	    if (got_eacces)	{
			__set_errno(EACCES);
		}
	
	    free(script_argv);
	    free(name - pathlen);
	    free(path_malloc);
	}
	
	return -1;
}

int
execlp(const char *file, const char *arg, ...)
{
	size_t argv_max = INITIAL_ARGV_MAX;
	const char *initial_argv[INITIAL_ARGV_MAX];
	const char **argv = initial_argv;
	va_list args;
	FILE *logfp;
	
	logfp = open_log();
	LOG(logfp, "\n*** miq_execlp ***\n");
	
	argv[0] = arg;
	
	va_start(args, arg);
	unsigned int i = 0;
	while (argv[i++] != NULL)	{
	    if (i == argv_max)	{
	        argv_max *= 2;
	        const char **nptr = realloc(argv == initial_argv ? NULL : argv,
	                                     argv_max * sizeof (const char *));
	        if (nptr == NULL)	{
	            if (argv != initial_argv)	{
	              free (argv);
				}
	            return -1;
	        }
	        if (argv == initial_argv)	{
	        	memcpy(nptr, argv, i * sizeof (const char *));
			}
	        argv = nptr;
	    }
	    argv[i] = va_arg (args, const char *);
	}
	va_end(args);
	
	int ret = execvp(file, (char *const *) argv);
	if (argv != initial_argv)	{
		free (argv);
	}
	
	return ret;
}

int
open(const char *file, int oflag, ...) 
{  
	int fd;
	int mode = 0;
	FILE *logfp;
   
	if (oflag & O_CREAT) {
		va_list arg;
		va_start (arg, oflag);
		mode = va_arg (arg, int);
		va_end (arg);
	}
	
	logfp = open_log();
	LOG2(logfp, "\n*** miq_open ***\n");
	LOG2(logfp, "miq_open, file: %s, oflag: 0x%x, mode: 0%o\n", file, oflag, mode);
	if (ext_is(file, ".vmx"))	log_trace();
	LOG2(logfp, "miq_open, calling open()...\n");
	fd = real_open(file, oflag, mode);
	LOG2(logfp, "miq_open, file: %s, open returned: %d\n", file, fd);
	return(fd);
}

int
open64(const char *file, int oflag, ...) 
{  
	int fd;
	int mode = 0;
	FILE *logfp;
   
	if (oflag & O_CREAT) {
		va_list arg;
		va_start (arg, oflag);
		mode = va_arg (arg, int);
		va_end (arg);
	}
	
	logfp = open_log();
	LOG2(logfp, "\n*** miq_open64 ***\n");
	LOG2(logfp, "miq_open64, file: %s, oflag: 0x%x, mode: 0%o\n", file, oflag, mode);
	if (ext_is(file, ".vmx"))	log_trace();
	LOG2(logfp, "miq_open64, calling open()...\n");
	fd = real_open64(file, oflag, mode);
	LOG2(logfp, "miq_open64, file: %s, open returned: %d\n", file, fd);
	return(fd);
}

int
creat(const char *file, mode_t mode) 
{  
	int fd;
	FILE *logfp;
	
	logfp = open_log();
	LOG2(logfp, "\n*** miq_creat ***\n");
	LOG2(logfp, "miq_creat, file: %s, mode: 0%o\n", file, mode);
	LOG2(logfp, "miq_creat, calling creat()...\n");
	fd = real_creat(file, mode);
	LOG2(logfp, "miq_creat, file: %s, creat returned: %d\n", file, fd);
	return(fd);
}

int
creat64(const char *file, mode_t mode) 
{  
	int fd;
	FILE *logfp;
	
	logfp = open_log();
	LOG2(logfp, "\n*** miq_creat64 ***\n");
	LOG2(logfp, "miq_creat64, file: %s, mode: 0%o\n", file, mode);
	LOG2(logfp, "miq_creat64, calling creat64()...\n");
	fd = real_creat64(file, mode);
	LOG2(logfp, "miq_creat, file: %s, creat returned: %d\n", file, fd);
	return(fd);
}

int
close(int fd)
{
	int rv;
	FILE *logfp;
	
	logfp = open_log();
	LOG4(logfp, "\n*** miq_close ***\n");
	LOG4(logfp, "miq_close, fd: %d\n", fd);
	
	if (miq_loglevel)	{
		if (fd == log_fd)	{
			LOG(logfp, "miq_close: Attempt tp close log_fd: %d\n", fd);
			return(0);
		}
	}
	LOG4(logfp, "miq_close, calling close()...\n");	
	rv = real_close(fd);
	LOG4(logfp, "miq_close, close returned: %d\n", rv);
	return(rv);
}

int
dup(int fd)
{
	int rv;
	FILE *logfp;
	
	logfp = open_log();
	LOG4(logfp, "\n*** miq_dup ***\n");
	LOG4(logfp, "miq_dup, fd: %d\n", fd);
	
	if (miq_loglevel)	{
		if (fd == log_fd)	{
			LOG(logfp, "miq_dup: Attempt to dup log_fd: %d\n", fd);
			return(0);
		}
	}
	LOG4(logfp, "miq_dup, calling dup()...\n");	
	rv = real_dup(fd);
	LOG4(logfp, "miq_dup, dup returned: %d\n", rv);
	return(rv);
}

int
dup2(int fd, int fd2)
{
	int rv;
	FILE *logfp;
	
	logfp = open_log();
	LOG4(logfp, "\n*** miq_dup2 ***\n");
	LOG4(logfp, "miq_dup2, fd: %d, fd2: %d\n", fd, fd2);
	
	if (miq_loglevel)	{
		if (fd == log_fd)	{
			LOG(logfp, "miq_dup2: Attempt tp dup log_fd: %d\n", fd);
			return(0);
		}
		if (fd2 == log_fd)	{
			LOG(logfp, "miq_dup2: Attempt tp dup to log_fd: %d\n", fd2);
			return(0);
		}
	}
	LOG4(logfp, "miq_dup2, calling dup2()...\n");	
	rv = real_dup2(fd, fd2);
	LOG4(logfp, "miq_dup2, dup2 returned: %d\n", rv);
	return(rv);
}
