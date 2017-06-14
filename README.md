# Rscons

Rscons is a software construction framework inspired by SCons and implemented
in Ruby.

[![Gem Version](https://badge.fury.io/rb/rscons.png)](http://badge.fury.io/rb/rscons)

## Installation

    $ gem install rscons

## Usage

### Standalone

Rscons provides a standalone executable ("rscons") with a command-line
interface. The rscons executable will read a build script (by default named
Rsconsfile or Rsconsfile.rb) and execute its contents.

### With Rake

Rscons can be used with rake as well. The same content that would be written
in Rsconsfile can be placed in a Rakefile. It could be placed within a rake
task block or split among multiple tasks.

## Example Build Scripts

### Example: Building a C Program

```ruby
Rscons::Environment.new do |env|
  env["CFLAGS"] << "-Wall"
  env.Program("program", Dir["src/**/*.c"])
end
```

### Example: Building a D Program

```ruby
Rscons::Environment.new do |env|
  env["DFLAGS"] << "-Wall"
  env.Program("program", Dir["src/**/*.d"])
end
```

### Example: Cloning an Environment

```ruby
main_env = Rscons::Environment.new do |env|
  # Store object files from sources under "src" in "build/main"
  env.build_dir("src", "build/main")
  env["CFLAGS"] = ["-DSOME_DEFINE", "-O3"]
  env["LIBS"] = ["SDL"]
  env.Program("program", Dir["src/**/*.cc"])
end

debug_env = main_env.clone do |env|
  # Store object files from sources under "src" in "build/debug"
  env.build_dir("src", "build/debug")
  env["CFLAGS"] -= ["-O3"]
  env["CFLAGS"] += ["-g", "-O0"]
  env.Program("program-debug", Dir["src/**/*.cc"])
end
```

### Example: Custom Builder

Custom builders are implemented as classes which extend from `Rscons::Builder`.
The builder must have a `run` method which is called to invoke the builder.
The `run` method should return the name of the target built on success, and
`false` on failure.

```ruby
class GenerateFoo < Rscons::Builder
  def run(target, sources, cache, env, vars)
    cache.mkdir_p(File.dirname(target))
    File.open(target, "w") do |fh|
      fh.puts <<EOF
#define GENERATED 42
EOF
    end
    target
  end
end

Rscons::Environment.new do |env|
  env.add_builder(GenerateFoo.new)
  env.GenerateFoo("foo.h", [])
  env.Program("a.out", Dir["*.c"])
end
```

### Example: Custom Builder That Only Regenerates When Necessary

```ruby
class CmdBuilder < Rscons::Builder
  def run(target, sources, cache, env, vars)
    cmd = ["cmd", "-i", sources.first, "-o", target]
    unless cache.up_to_date?(target, cmd, sources, env)
      cache.mkdir_p(File.dirname(target))
      system(cmd)
      cache.register_build(target, cmd, sources, env)
    end
    target
  end
end

Rscons::Environment.new do |env|
  env.add_builder(CmdBuilder.new)
  env.CmdBuilder("foo.gen", "foo_gen.cfg")
end
```

### Example: Custom Builder That Generates Multiple Output Files

```ruby
class CModuleGenerator < Rscons::Builder
  def run(target, sources, cache, env, vars)
    c_fname = target
    h_fname = target.sub(/\.c$/, ".h")
    cmd = ["generate_c_and_h", sources.first, c_fname, h_fname]
    unless cache.up_to_date?([c_fname, h_fname], cmd, sources, env)
      cache.mkdir_p(File.dirname(target))
      system(cmd)
      cache.register_build([c_fname, h_fname], cmd, sources, env)
    end
    target
  end
end

Rscons::Environment.new do |env|
  env.add_builder(CModuleGenerator.new)
  env.CModuleGenerator("build/foo.c", "foo_gen.cfg")
end
```

### Example: Custom Builder Using Builder#standard_build()

The `standard_build` method from the `Rscons::Builder` base class can be used
when the builder needs to execute a system command to produce the target file.
The `standard_build` method will return the correct value so its return value
can be used as the return value from the `run` method.

```ruby
class CmdBuilder < Rscons::Builder
  def run(target, sources, cache, env, vars)
    cmd = ["cmd", "-i", sources.first, "-o", target]
    standard_build("CmdBld #{target}", target, cmd, sources, env, cache)
  end
end

Rscons::Environment.new do |env|
  env.add_builder(CmdBuilder.new)
  env.CmdBuilder("foo.gen", "foo_gen.cfg")
end
```

### Example: Custom Builder Using Environment#add_builder()

The `add_builder` method of the `Rscons::Environment` class optionally allows
you to define and register a builder by providing a name and action block. This
can be useful if the builder you are trying to define is easily expressed as a
short ruby procedure. When `add_builder` is called in this manner a new builder
will be registered with the environment with the given name. When this builder
is used it will call the provided block in order to build the target.

```ruby
Rscons::Environment.new do |env|
  env.add_builder(:JsonToYaml) do |target, sources, cache, env, vars|
    unless cache.up_to_date?(target, :JsonToYaml, sources, env)
      cache.mkdir_p(File.dirname(target))
      File.open(target, 'w') do |f|
        f.write(YAML.dump(JSON.load(IO.read(sources.first))))
      end
      cache.register_build(target, :JsonToYaml, sources, env)
    end
    target
  end
  env.JsonToYaml('foo.yml','foo.json')
end
```

### Example: Using different compilation flags for some sources

```ruby
Rscons::Environment.new do |env|
  env["CFLAGS"] = ["-O3", "-Wall", "-DDEFINE"]
  env.add_build_hook do |build_op|
    if build_op[:target] =~ %r{build/third-party}
      build_op[:vars]["CFLAGS"] -= ["-Wall"]
    end
  end
  env.build_dir("src", "build")
  env.Program("program", Dir["**/*.cc"])
end
```

### Example: Creating a static library

```ruby
Rscons::Environment.new do |env|
  env.Library("mylib.a", Dir["src/**/*.c"])
end
```

### Example: Creating a C++ parser source from a Yacc/Bison input file

```ruby
Rscons::Environment.new do |env|
  env.CFile("#{env.build_root}/parser.tab.cc", "parser.yy")
end
```

## Details

### Environments

The Environment is the main top-level object that Rscons operates with. An
Environment must be created by the user in order to build anything. All build
targets are registered within an Environment. In many cases only a single
Environment will be needed, but more than one can be created (either from
scratch or by cloning another existing Environment) if needed.

An Environment consists of:

* a collection of builders
* a collection of construction variables used by those builders
* a mapping of build directories from source directories
* a default build root to apply if no specific build directories are matched
* a collection of user-defined build targets
* a collection of user-defined build hooks

When cloning an environment, by default the construction variables, builders,
build hooks, build directories, and build root are cloned, but the new
environment does not inherit any of the registered build targets.

The set of environment attributes that are cloned is controllable via the
`:clone` option to the `#clone` method.
For example, `env.clone(clone: [:variables, :builders])` will include
construction variables, and builders but not build hooks, build directories, or
the build root.

The set of pending targets is never cloned.

Cloned environments contain "deep copies" of construction variables.
For example, in:

```ruby
base_env = Rscons::Environment.new
base_env["CPPPATH"] = ["one", "two"]
cloned_env = base_env.clone
cloned_env["CPPPATH"] << "three"
```

`base_env["CPPPATH"]` will not include "three".

### Builders

Builders are the workhorses that Rscons uses to execute build operations.
Each builder is specialized to perform a particular operation.

Rscons ships with a number of builders:

* Command, which executes a user-defined command to produce the target.
* Copy, which is identical to Install.
* CFile, which builds a C or C++ source file from a lex or yacc input file.
* Disassemble, which disassembles an object file to a disassembly listing.
* Install, which installs files or directories to a specified destination.
* Library, which collects object files into a static library archive file.
* Object, which compiles source files to produce an object file.
* Preprocess, which invokes the C/C++ preprocessor on a source file.
* Program, which links object files to produce an executable.
* SharedLibrary, which links object files to produce a dynamically loadable
  library.
* SharedObject, which compiles source files to produce an object file, in a way
  that is able to be used to create a shared library.

If you want to create an Environment that does not contain any builders,
you can use the `:exclude_builders` key to the Environment constructor.

#### Command

```ruby
env.Command(target, sources, "CMD" => command)
# Example
env.Command("docs.html", "docs.md",
    "CMD" => ["pandoc", "-fmarkdown", "-thtml", "-o${_TARGET}", "${_SOURCES}"],
    "CMD_DESC" => "PANDOC")
```

The command builder executes a user-defined command in order to produce the
desired target file based on the provided source files.

#### CFile

```ruby
env.CFile(target, source)
# Example
env.CFile("parser.c", "parser.y")
```

The CFile builder will generate a C or C++ source file from a lex (.l, .ll)
or yacc (.y, .yy) input file.

#### Disassemble

```ruby
env.Disassemble(target, source)
# Example
env.Disassemble("module.dis", "module.o")
```

The Disassemble builder generates a disassembly listing using objdump from
and object file.

#### Install

```ruby
env.Install(destination, sources)
# Example
env.Install("dist/bin", "app.exe")
env.Install("dist/share", "share")
```

#### Library

```ruby
env.Library(target, sources)
# Example
env.Library("lib.a", Dir["src/**/*.c"])
```

The Library builder creates a static library archive from the given source
files.

#### Object

```ruby
env.Object(target, sources)
# Example
env.Object("module.o", "module.c")
```

The Object builder compiles the given sources to an object file. Although it
can be called explicitly, it is more commonly implicitly called by the Program
builder.

#### Preprocess

```ruby
env.Preprocess(target, source)
# Example
env.Preprocess("module-preprocessed.cc", "module.cc")
```

The Preprocess builder invokes either `${CC}` or `${CXX}` (depending on if the
source contains an extension in `${CXXSUFFIX}` or not) and writes the
preprocessed output to the target file.

#### Program

```ruby
env.Program(target, sources)
# Example
env.Program("myprog", Dir["src/**/*.cc"])
```

The Program builder compiles and links the given sources to an executable file.
Object files or source files can be given as `sources`. A platform-dependent
program suffix will be appended to the target name if one is not specified.
This can be controlled with the `PROGSUFFIX` construction variable.

#### SharedLibrary

```ruby
env.SharedLibrary(target, sources)
# Example
env.SharedLibrary("mydll", Dir["src/**/*.cc"])
```

The SharedLibrary builder compiles and links the given sources to a dynamically
loadable library. Object files or source files can be given as `sources`.
A platform-dependent prefix and suffix will be appended to the target name if
they are not specified by the user. These values can be controlled by
overriding the `SHLIBPREFIX` and `SHLIBSUFFIX` construction variables.

#### SharedObject

```ruby
env.SharedObject(target, sources)
# Example
env.SharedObject("lib_module.o", "lib_module.c")
```

The SharedObject builder compiles the given sources to an object file. Any
compilation flags necessary to build the object file in a manner that allows it
to be used to create a shared library are added. Although it can be called
explicitly, it is more commonly implicitly called by the SharedLibrary builder.

### Construction Variables

Construction variables are used to define the toolset and any build options
that Rscons will use to build a project. The default construction variable
values are configured to build applications using gcc. However, all
construction variables can be overridden by the user.

| Name | Type | Description | Default |
| --- | --- | --- | --- |
| AR | String | Static library archiver executable | "ar" |
| ARCMD | Array | Static library archiver command line | ["${AR}", "${ARFLAGS}", "${_TARGET}", "${_SOURCES}"] |
| ARFLAGS | Array | Static library archiver flags | ["rcs"] |
| AS | String | Assembler executable | "${CC}" |
| ASCMD | Array | Assembler command line | ["${AS}", "-c", "-o", "${_TARGET}", "${ASDEPGEN}", "${INCPREFIX}${ASPPPATH}", "${ASPPFLAGS}", "${ASFLAGS}", "${_SOURCES}"] |
| ASDEPGEN | Array | Assembly dependency generation flags | ["-MMD", "-MF", "${_DEPFILE}"] |
| ASFLAGS | Array | Assembler flags | [] |
| ASPPFLAGS | Array | Assembler preprocessor flags | ["${CPPFLAGS}"] |
| ASPPPATH | Array | Assembler preprocessor path | ["${CPPPATH}"] |
| ASSUFFIX | Array | Assembly file suffixes | [".S"] |
| CC | String | C compiler executable | "gcc" |
| CCCMD | Array | C compiler command line | ["${CC}", "-c", "-o", "${_TARGET}", "${CCDEPGEN}", "${INCPREFIX}${CPPPATH}", "${CPPFLAGS}", "${CFLAGS}", "${CCFLAGS}", "${_SOURCES}"] |
| CCDEPGEN | Array | C compiler dependency generation flags | ["-MMD", "-MF", "${_DEPFILE}"] |
| CCFLAGS | Array | Common flags for both C and C++ compiler | [] |
| CFLAGS | Array | C compiler flags | [] |
| CPP_CMD | Array | Preprocess command line | ["${_PREPROCESS_CC}", "-E", "${_PREPROCESS_DEPGEN}", "-o", "${_TARGET}", "${INCPREFIX}${CPPPATH}", "${CPPFLAGS}", "${_SOURCES}"] |
| CPP_TARGET_SUFFIX | String | Suffix used for crt:preprocess target filename. | ".c" |
| CPPDEFINES | Array | C preprocessor defines | [] |
| CPPDEFPREFIX | String | Prefix used for C preprocessor to introduce a define | "-D" |
| CPPFLAGS | Array | C preprocessor flags | ["${CPPDEFPREFIX}${CPPDEFINES}"] |
| CPPPATH | Array | C preprocessor path | [] |
| CSUFFIX | Array | C source file suffixes | [".c"] |
| CXX | String | C++ compiler executable | "g++" |
| CXXCMD | Array | C++ compiler command line | ["${CXX}", "-c", "-o", "${_TARGET}", "${CXXDEPGEN}", "${INCPREFIX}${CPPPATH}", "${CPPFLAGS}", "${CXXFLAGS}", "${CCFLAGS}", "${_SOURCES}"] |
| CXXDEPGEN | Array | C++ compiler dependency generation flags | ["-MMD", "-MF", "${_DEPFILE}"] |
| CXXFLAGS | Array | C++ compiler flags | [] |
| CXXSUFFIX | Array | C++ source file suffixes | [".cc", ".cpp", ".cxx", ".C"] |
| D_IMPORT_PATH | Array | D compiler import path | [] |
| DC | String | D compiler executable | "gdc" |
| DCCMD | Array | D compiler command line | ["${DC}", "-c", "-o", "${_TARGET}", "${INCPREFIX}${D_IMPORT_PATH}", "${DFLAGS}", "${_SOURCES}"] |
| DEPFILESUFFIX | String | Dependency file suffix for Makefile-style dependency rules emitted by the compiler (used internally for temporary dependency files used to determine a source file's dependencies) | ".mf" |
| DFLAGS | Array | D compiler flags | [] |
| DISASM_CMD | Array | Disassemble command line | ["${OBJDUMP}", "${DISASM_FLAGS}", "${_SOURCES}"] |
| DISASM_FLAGS | Array | Disassemble flags | ["--disassemble", "--source"] |
| DSUFFIX | String/Array | Default D source file suffix | ".d" |
| INCPREFIX | String | Prefix used for C preprocessor to add an include path | "-I" |
| LD | String |  nil | Linker executable (automatically determined when nil) | nil (if nil, ${CC}, ${CXX}, or ${DC} is used depending on the sources being linked) |
| LDCMD | Array | Link command line | ["${LD}", "-o", "${_TARGET}", "${LDFLAGS}", "${_SOURCES}", "${LIBDIRPREFIX}${LIBPATH}", "${LIBLINKPREFIX}${LIBS}"] |
| LDFLAGS | Array | Linker flags | [] |
| LEX | String | Lex executable | "flex" |
| LEX_CMD | Array | Lex command line | ["${LEX}", "${LEX_FLAGS}", "-o", "${_TARGET}", "${_SOURCES}"] |
| LEX_FLAGS | Array | Lex flags | [] |
| LEXSUFFIX | Array | Lex input file suffixes | [".l", ".ll"] |
| LIBDIRPREFIX | String | Prefix given to linker to add a library search path | "-L" |
| LIBLINKPREFIX | String | Prefix given to linker to add a library to link with | "-l" |
| LIBPATH | Array | Library load path | [] |
| LIBS | Array | Libraries to link with | [] |
| LIBSUFFIX | String/Array | Default static library file suffix | ".a" |
| OBJDUMP | String | Objdump executable | "objdump" |
| OBJSUFFIX | String/Array | Default object file suffix | ".o" |
| PROGSUFFIX | String | Default program suffix. | Windows: ".exe", POSIX: "" |
| SHCC | String | Shared object C compiler | "${CC}" |
| SHCCCMD | Array | Shared object C compiler command line | ["${SHCC}", "-c", "-o", "${_TARGET}", "${CCDEPGEN}", "${INCPREFIX}${CPPPATH}", "${CPPFLAGS}", "${SHCFLAGS}", "${SHCCFLAGS}", "${_SOURCES}"] |
| SHCCFLAGS | Array | Shared object C and C++ compiler flags | Windows: ["${CCFLAGS}"], POSIX: ["${CCFLAGS}", -fPIC"] |
| SHCFLAGS | Array | Shared object C compiler flags | ["${CFLAGS}"] |
| SHCXX | String | Shared object C++ compiler | "${CXX}" |
| SHCXXCMD | Array | Shared object C++ compiler command line | ["${SHCXX}", "-c", "-o", "${_TARGET}", "${CXXDEPGEN}", "${INCPREFIX}${CPPPATH}", "${CPPFLAGS}", "${SHCXXFLAGS}", "${SHCCFLAGS}", "${_SOURCES}"] |
| SHCXXFLAGS | Array | Shared object C++ compiler flags | ["${CXXFLAGS}"] |
| SHDC | String | Shared object D compiler | "gdc" |
| SHDCCMD | Array | Shared object D compiler command line | ["${SHDC}", "-c", "-o", "${_TARGET}", "${INCPREFIX}${D_IMPORT_PATH}", "${SHDFLAGS}", "${_SOURCES}"] |
| SHDFLAGS | Array | Shared object D compiler flags | Windows: ["${DFLAGS}"], POSIX: ["${DFLAGS}", "-fPIC"] |
| SHLD | String | Shared library linker | nil (if nil, ${SHCC}, ${SHCXX}, or ${SHDC} is used depending on the sources being linked) |
| SHLDCMD | Array | Shared library linker command line | ["${SHLD}", "-o", "${_TARGET}", "${SHLDFLAGS}", "${_SOURCES}", "${SHLIBDIRPREFIX}${LIBPATH}", "${SHLIBLINKPREFIX}${LIBS}"] |
| SHLDFLAGS | Array | Shared library linker flags | ["${LDFLAGS}", "-shared"] |
| SHLIBDIRPREFIX | String | Prefix given to shared library linker to add a library search path | "-L" |
| SHLIBLINKPREFIX | String | Prefix given to shared library linker to add a library to link with | "-l" |
| SHLIBPREFIX | String | Shared library file name prefix | Windows: "", POSIX: "lib" |
| SHLIBSUFFIX | String | Shared library file name suffix | Windows: ".dll", POSIX: ".so" |
| SIZE | String | Size executable. | "size" |
| YACC | String | Yacc executable | "bison" |
| YACC_CMD | Array | Yacc command line | ["${YACC}", "${YACC_FLAGS}", "-o", "${_TARGET}", "${_SOURCES}"] |
| YACC_FLAGS | Array | Yacc flags | ["-d"] |
| YACCSUFFIX | Array | Yacc input file suffixes | [".y", ".yy"] |

### Build Hooks

Environments can have build hooks which are added with `env.add_build_hook()`.
Build hooks are invoked immediately before a builder executes.
Build hooks can modify the construction variables in use for the build
operation.
They can also register new build targets.

Environments can also have post-build hooks added with `env.add_post_build_hook()`.
Post-build hooks are only invoked if the build operation was a success.
Post-build hooks can invoke commands using the newly-built files, or register
new build targets.

Each build hook block will be invoked for every build operation, so the block
should test the target or sources if its action should only apply to some
subset of build targets or source files.

Example build hook:

```ruby
Rscons::Environment.new do |env|
  # Build third party sources without -Wall
  env.add_build_hook do |build_op|
    if build_op[:builder].name == "Object" and
      build_op[:sources].first =~ %r{src/third-party}
      build_op[:vars]["CFLAGS"] -= ["-Wall"]
    end
  end
end
```

The `build_op` parameter to the build hook block is a Hash describing the
build operation with the following keys:
* `:builder` - `Builder` instance in use
* `:env` - `Environment` calling the build hook; note that this may be
  different from the Environment that the build hook was added to in the case
  that the original Environment was cloned with build hooks!
* `:target` - `String` name of the target file
* `:sources` - `Array` of the source files
* `:vars` - `Rscons::VarSet` containing the construction variables to use.
  The build hook can overwrite entries in `build_op[:vars]` to alter the
  construction variables in use for this specific build operation.

### Phony Targets

A build target name given as a Symbol instead of a String is interpreted as a
"phony" target.
Phony targets operate similarly to normal build targets, except that a file is
not expected to be produced by the builder.
Phony targets will still be "rebuilt" if any source or the command is out of
date.

### Explicit Dependencies

A target can be marked as depending on another file that Rscons would not
otherwise know about via the `Environment#depends` function. For example,
to force the linker to re-link a Program output when a linker script changes:

```ruby
Rscons::Environment.new do |env|
  env.Program("a.out", "foo.c", "LDFLAGS" => %w[-T linker_script.ld])
  env.depends("a.out", "linker_script.ld")
end
```

You can pass multiple dependency files to `Environment#depends`:

```ruby
env.depends("my_app", "config/link.ld", "README.txt", *Dir.glob("assets/**/*"))
```

### Construction Variable Naming

* uppercase strings - the default construction variables that Rscons uses
* strings beginning with "_" - set and used internally by builders
* symbols, lowercase strings - reserved as user-defined construction variables

### API documentation

Documentation for the complete Rscons API can be found at
http://www.rubydoc.info/github/holtrop/rscons/master.

## Release Notes

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
