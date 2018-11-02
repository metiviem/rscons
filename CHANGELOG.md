## ChangeLog

### v1.17.0

#### New Features

- allow construction variable expansion on `true` and `false` values.
- remove makefile target name check when parsing dependencies

### v1.16.0

#### New Features

- Add `Rscons.glob`
- Support command-line variables
- improve debuggability of cache.up_to_date?
- allow passing a VarSet into cache methods

#### Fixes

- generate dependencies for D builds

### v1.15.0

- allow json 1.x or 2.x

### v1.14.0

#### New Features

- #45 - Add Rscons::VarSet#values_at

#### Fixes

- #44 - Environment#print_builder_run_message should support string commands

### v1.13.0

#### New Features

- #43 - Add ability to record side-effect file production

### v1.12.0

#### New Features

- #40 - env.depends should imply env.build_after
- #41 - be more colorful

#### Fixes

- #39 - wait for in-progress subcommands to complete on build failure
- #42 - cloned Environments should inherit n_threads

### v1.11.1

#### Fixes

- fix the circular build dependency detection logic

### v1.11.0

#### New Features

- Change default Environment :clone option to :all to clone all attributes
- #38 - raise error when circular dependencies are found
- #34 - Allow overriding n_threads on a per-Environment level

#### Fixes

- #35 - env.build_after should expand paths
- #36 - SHCFLAGS and SHCXXFLAGS should inherit non-SH flags by default
- #37 - Fix non-blocking thread-wait if Rscons.n_threads is set to 0

### v1.10.0

#### New Features

- #23 - add parallelization - builds are now parallelized by default
- #31 - add LEXSUFFIX, YACCSUFFIX construction variables
- #30 - place object files for absolute source paths under build_root
- #28 - support redirecting standard output using the Command builder
- Always use a build root and default it to "build"
- Add builder features
- #8 - add SharedObject and SharedLibrary builders

#### Fixes

- expand target and source paths before calling Builder#create_build_target
- #29 - fix PROGSUFFIX handling
- #32 - Pre-build hooks do not respect modified key values

### v1.9.3

- Environment#parse_flags should put -std=XXX flags in CCFLAGS, not CFLAGS

### v1.9.2

- allow phony targets in conjunction with build roots

### v1.9.1

- change *SUFFIX defaults to arrays
- add various C++ file suffixes
- use ${INCPREFIX} instead of hard-coded "-I" in Preprocess builder

### v1.9.0

#### New Features

- #6 - add Install and Copy builders
- #22 - allow overriding Command builder short description with CMD_DESC variable
- #24 - add "rscons" executable
- #25 - add support for phony targets given as Symbols instead of Strings
- #26 - support registering multiple build targets with the same target name
- #27 - add Directory builder

#### Fixes

- #20 - fix variable references that expand to arrays in build target sources
- #21 - rework Preprocess builder to consider deep dependencies
- fix Rscons.set_suffix to append the given suffix if the filename has none
- remove ${CFLAGS} from default CPP_CMD

### v1.8.1

- fix Environment#dump when construction variables are symbols

### v1.8.0

- new Command builder to execute arbitrary user commands
- new SimpleBuilder class
  - create new builders quickly by passing a block to Environment#add_builder
- improved YARD documentation
- add Environment#dump to debug Environment construction variables

### v1.7.0

- allow build hooks to register new build targets
- add post-build hooks (register with Environment#add_post_build_hook)
- clear all build targets after processing an Environment
- allow trailing slashes in arguments to Environment#build_dir

### v1.6.1

- add DEPFILESUFFIX construction variable to override dependency file suffix
- fix Environment#depends to expand its arguments for construction variables

### v1.6.0

- support lambdas as construction variable values

### v1.5.0

- add "json" as a runtime dependency
- update construction variables to match SCons more closely
  - add CPPDEFPREFIX, INCPREFIX, CPPDEFINES, CCFLAGS, LIBDIRPREFIX, and LIBLINKPREFIX
- add Environment#shell
- add Environment#parse_flags, #parse_flags!, #merge_flags
- unbuffer $stdout by default
- add PROGSUFFIX construction variable (defaults to .exe on MinGW/Cygwin)
- add Rscons::BuildTarget and Builder#create_build_target
- update specs to RSpec 3.x and fix to run on MinGW/Cygwin/Linux
- add YARD documentation to get to 100% coverage

### v1.4.3

- fix builders properly using construction variable overrides
- expand nil construction variables to empty strings

### v1.4.2

- add Environment#expand_path
- expand construction variable references in builder targets and sources before invoking builder

### v1.4.1

- fix invoking a builder with no sources while a build root defined

### v1.4.0

- add CFile builder
- add Disassemble builder
- add Preprocess builder
- pass the Environment object to build hooks in the :env key of the build_op parameter
- expand target/source paths beginning with "^/" to be relative to the Environment's build root
- many performance improvements, including:
  - use JSON instead of YAML for the cache to improve loading speed (Issue #7)
  - store a hash of the build command instead of the full command contents in the cache
  - implement copy-on-write semantics for construction variables when cloning Environments
  - only load the cache once instead of on each Environment#process
  - only write the cache when something has changed
- fix Cache#mkdir_p to handle relative paths (Issue #5)
- flush the cache to disk if a builder raises an exception (Issue #4)

### v1.3.0

- change Environment#execute() options parameter to accept the following options keys:
  - :env to pass an environment Hash to Kernel#system
  - :options to pass an options Hash to Kernel#system

### v1.2.0

- add :clone option to Environment#clone to control exactly which Environment attributes are cloned
- allow nil to be passed in to Environment#build_root=

### v1.1.0

- Change Cache#up_to_date?() and #register_build() to accept a single target
  file or an array of target file names
