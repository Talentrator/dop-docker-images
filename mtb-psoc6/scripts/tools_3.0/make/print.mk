# Read by psoc6-build after a project's Makefile: prints the variables it uses.
__mtb_print:
	@$(foreach v,APPNAME CONFIG TARGET CORE COMPONENTS DISABLE_COMPONENTS DEFINES SOURCES INCLUDES VFP_SELECT CFLAGS CXXFLAGS ASFLAGS LDFLAGS LDLIBS LINKER_SCRIPT,printf '%s\n' '__MTB_VAR $(v)=$(strip $($(v)))';)
