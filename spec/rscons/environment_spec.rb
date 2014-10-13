module Rscons
  describe Environment do
    describe "#initialize" do
      it "adds the default builders when they are not excluded" do
        env = Environment.new
        expect(env.builders.size).to be > 0
        expect(env.builders.map {|name, builder| builder.is_a?(Builder)}.all?).to be_truthy
        expect(env.builders.find {|name, builder| name == "Object"}).to_not be_nil
        expect(env.builders.find {|name, builder| name == "Program"}).to_not be_nil
        expect(env.builders.find {|name, builder| name == "Library"}).to_not be_nil
      end

      it "excludes the default builders with exclude_builders: :all" do
        env = Environment.new(exclude_builders: true)
        expect(env.builders.size).to eq 0
      end

      context "when a block is given" do
        it "yields self and invokes #process()" do
          env = Environment.new do |env|
            expect(env).to receive(:process)
          end
        end
      end
    end

    describe "#clone" do
      it 'creates unique copies of each construction variable' do
        env = Environment.new
        env["CPPPATH"] << "path1"
        env2 = env.clone
        env2["CPPPATH"] << "path2"
        expect(env["CPPPATH"]).to eq ["path1"]
        expect(env2["CPPPATH"]).to eq ["path1", "path2"]
      end

      it "supports nil, false, true, String, Symbol, Array, Hash, and Integer variables" do
        env = Environment.new
        env["nil"] = nil
        env["false"] = false
        env["true"] = true
        env["String"] = "String"
        env["Symbol"] = :Symbol
        env["Array"] = ["a", "b"]
        env["Hash"] = {"a" => "b"}
        env["Integer"] = 1234
        env2 = env.clone
        expect(env2["nil"]).to be_nil
        expect(env2["false"].object_id).to eq(false.object_id)
        expect(env2["true"].object_id).to eq(true.object_id)
        expect(env2["String"]).to eq("String")
        expect(env2["Symbol"]).to eq(:Symbol)
        expect(env2["Array"]).to eq(["a", "b"])
        expect(env2["Hash"]).to eq({"a" => "b"})
        expect(env2["Integer"]).to eq(1234)
      end

      context "when a block is given" do
        it "yields self and invokes #process()" do
          env = Environment.new
          env.clone do |env2|
            expect(env2).to receive(:process)
          end
        end
      end
    end

    describe "#add_builder" do
      it "adds the builder to the list of builders" do
        env = Environment.new(exclude_builders: true)
        expect(env.builders.keys).to eq []
        env.add_builder(Rscons::Builders::Object.new)
        expect(env.builders.keys).to eq ["Object"]
      end

      it "adds a new simple builder to the list of builders" do
        env = Environment.new(exclude_builders: true)
        expect(env.builders.keys).to eq []
        env.add_builder(:Foo) {}
        expect(env.builders.keys).to eq ["Foo"]
      end
    end

    describe "#get_build_fname" do
      context "with no build directories" do
        it "returns the name of the source file with suffix changed" do
          env = Environment.new
          expect(env.get_build_fname("src/dir/file.c", ".o")).to eq "src/dir/file.o"
          expect(env.get_build_fname("src\\dir\\other.d", ".a")).to eq "src/dir/other.a"
          expect(env.get_build_fname("source.cc", ".o")).to eq "source.o"
        end

        context "with a build_root" do
          it "uses the build_root unless the path is absolute" do
            env = Environment.new
            env.build_root = "build/proj"
            expect(env.get_build_fname("src/dir/file.c", ".o")).to eq "build/proj/src/dir/file.o"
            expect(env.get_build_fname("/some/lib.c", ".a")).to eq "/some/lib.a"
            expect(env.get_build_fname("C:\\abspath\\mod.cc", ".o")).to eq "C:/abspath/mod.o"
            expect(env.get_build_fname("build\\proj\\generated.c", ".o")).to eq "build/proj/generated.o"
            expect(env.get_build_fname("build/proj.XX", ".yy")).to eq "build/proj/build/proj.yy"
          end
        end
      end

      context "with build directories" do
        it "uses the build directories to create the output file name" do
          env = Environment.new
          env.build_dir("src", "bld")
          env.build_dir(%r{^libs/([^/]+)}, 'build/libs/\1')
          expect(env.get_build_fname("src/input.cc", ".o")).to eq "bld/input.o"
          expect(env.get_build_fname("libs/lib1/some/file.c", ".o")).to eq "build/libs/lib1/some/file.o"
          expect(env.get_build_fname("libs/otherlib/otherlib.cc", ".o")).to eq "build/libs/otherlib/otherlib.o"
          expect(env.get_build_fname("other_directory/o.d", ".a")).to eq "other_directory/o.a"
        end

        context "with a build_root" do
          it "uses the build_root unless a build directory matches or the path is absolute" do
            env = Environment.new
            env.build_dir("src", "bld")
            env.build_dir(%r{^libs/([^/]+)}, 'build/libs/\1')
            env.build_root = "bldit"

            expect(env.get_build_fname("src/input.cc", ".o")).to eq "bld/input.o"
            expect(env.get_build_fname("libs/lib1/some/file.c", ".o")).to eq "build/libs/lib1/some/file.o"
            expect(env.get_build_fname("libs/otherlib/otherlib.cc", ".o")).to eq "build/libs/otherlib/otherlib.o"
            expect(env.get_build_fname("other_directory/o.d", ".a")).to eq "bldit/other_directory/o.a"
            expect(env.get_build_fname("bldit/some/mod.d", ".a")).to eq "bldit/some/mod.a"
          end
        end
      end
    end

    describe "#[]" do
      it "allows reading construction variables" do
        env = Environment.new
        env["CFLAGS"] = ["-g", "-Wall"]
        expect(env["CFLAGS"]).to eq ["-g", "-Wall"]
      end
    end

    describe "#[]=" do
      it "allows writing construction variables" do
        env = Environment.new
        env["CFLAGS"] = ["-g", "-Wall"]
        env["CFLAGS"] -= ["-g"]
        env["CFLAGS"] += ["-O3"]
        expect(env["CFLAGS"]).to eq ["-Wall", "-O3"]
        env["other_var"] = "val33"
        expect(env["other_var"]).to eq "val33"
      end
    end

    describe "#append" do
      it "allows adding many construction variables at once" do
        env = Environment.new
        env["CFLAGS"] = ["-g"]
        env["CPPPATH"] = ["inc"]
        env.append("CFLAGS" => ["-Wall"], "CPPPATH" => ["include"])
        expect(env["CFLAGS"]).to eq ["-Wall"]
        expect(env["CPPPATH"]).to eq ["include"]
      end
    end

    describe "#process" do
      it "runs builders for all of the targets specified" do
        env = Environment.new
        env.Program("a.out", "main.c")

        cache = "cache"
        expect(Cache).to receive(:instance).and_return(cache)
        expect(cache).to receive(:clear_checksum_cache!)
        expect(env).to receive(:run_builder).with(anything, "a.out", ["main.c"], cache, {}).and_return(true)
        expect(cache).to receive(:write)

        env.process
      end

      it "builds dependent targets first" do
        env = Environment.new
        env.Program("a.out", "main.o")
        env.Object("main.o", "other.cc")

        cache = "cache"
        expect(Cache).to receive(:instance).and_return(cache)
        expect(cache).to receive(:clear_checksum_cache!)
        expect(env).to receive(:run_builder).with(anything, "main.o", ["other.cc"], cache, {}).and_return("main.o")
        expect(env).to receive(:run_builder).with(anything, "a.out", ["main.o"], cache, {}).and_return("a.out")
        expect(cache).to receive(:write)

        env.process
      end

      it "raises a BuildError when building fails" do
        env = Environment.new
        env.Program("a.out", "main.o")
        env.Object("main.o", "other.cc")

        cache = "cache"
        expect(Cache).to receive(:instance).and_return(cache)
        expect(cache).to receive(:clear_checksum_cache!)
        expect(env).to receive(:run_builder).with(anything, "main.o", ["other.cc"], cache, {}).and_return(false)
        expect(cache).to receive(:write)

        expect { env.process }.to raise_error BuildError, /Failed.to.build.main.o/
      end

      it "writes the cache when the Builder raises an exception" do
        env = Environment.new
        env.Object("module.o", "module.c")

        cache = "cache"
        expect(Cache).to receive(:instance).and_return(cache)
        expect(cache).to receive(:clear_checksum_cache!)
        allow(env).to receive(:run_builder) do |builder, target, sources, cache, vars|
          raise "Ruby exception thrown by builder"
        end
        expect(cache).to receive(:write)

        expect { env.process }.to raise_error RuntimeError, /Ruby exception thrown by builder/
      end
    end

    describe "#clear_targets" do
      it "resets @targets to an empty hash" do
        env = Environment.new
        env.Program("a.out", "main.o")
        expect(env.instance_variable_get(:@targets).keys).to eq(["a.out"])

        env.clear_targets

        expect(env.instance_variable_get(:@targets).keys).to eq([])
      end
    end

    describe "#build_command" do
      it "returns a command based on the variables in the Environment" do
        env = Environment.new
        env["path"] = ["dir1", "dir2"]
        env["flags"] = ["-x", "-y", "${specialflag}"]
        env["specialflag"] = "-z"
        template = ["cmd", "-I${path}", "${flags}", "${_source}", "${_dest}"]
        cmd = env.build_command(template, "_source" => "infile", "_dest" => "outfile")
        expect(cmd).to eq ["cmd", "-Idir1", "-Idir2", "-x", "-y", "-z", "infile", "outfile"]
      end
    end

    describe "#expand_varref" do
      it "returns the fully expanded variable reference" do
        env = Environment.new
        env["path"] = ["dir1", "dir2"]
        env["flags"] = ["-x", "-y", "${specialflag}"]
        env["specialflag"] = "-z"
        env["foo"] = {}
        expect(env.expand_varref(["-p${path}", "${flags}"])).to eq ["-pdir1", "-pdir2", "-x", "-y", "-z"]
        expect(env.expand_varref("foo")).to eq "foo"
        expect {env.expand_varref("${foo}")}.to raise_error /Unknown.varref.type/
        expect(env.expand_varref("${specialflag}")).to eq "-z"
        expect(env.expand_varref("${path}")).to eq ["dir1", "dir2"]
      end
    end

    describe "#execute" do
      context "with echo: :short" do
        context "with no errors" do
          it "prints the short description and executes the command" do
            env = Environment.new(echo: :short)
            expect(env).to receive(:puts).with("short desc")
            expect(env).to receive(:system).with(*Rscons.command_executer, "a", "command").and_return(true)
            env.execute("short desc", ["a", "command"])
          end
        end

        context "with errors" do
          it "prints the short description, executes the command, and prints the failed command line" do
            env = Environment.new(echo: :short)
            expect(env).to receive(:puts).with("short desc")
            expect(env).to receive(:system).with(*Rscons.command_executer, "a", "command").and_return(false)
            expect($stdout).to receive(:write).with("Failed command was: ")
            expect(env).to receive(:puts).with("a command")
            env.execute("short desc", ["a", "command"])
          end
        end
      end

      context "with echo: :command" do
        it "prints the command executed and executes the command" do
          env = Environment.new(echo: :command)
          expect(env).to receive(:puts).with("a command '--arg=val with spaces'")
          expect(env).to receive(:system).with({modified: :environment}, *Rscons.command_executer, "a", "command", "--arg=val with spaces", {opt: :val}).and_return(false)
          env.execute("short desc", ["a", "command", "--arg=val with spaces"], env: {modified: :environment}, options: {opt: :val})
        end
      end
    end

    describe "#method_missing" do
      it "calls the original method missing when the target method is not a known builder" do
        env = Environment.new
        expect {env.foobar}.to raise_error /undefined method .foobar./
      end

      it "records the target when the target method is a known builder" do
        env = Environment.new
        expect(env.instance_variable_get(:@targets)).to eq({})
        env.Object("target.o", ["src1.c", "src2.c"], var: "val")
        target = env.instance_variable_get(:@targets)["target.o"]
        expect(target).to_not be_nil
        expect(target[:builder].is_a?(Builder)).to be_truthy
        expect(target[:sources]).to eq ["src1.c", "src2.c"]
        expect(target[:vars]).to eq({var: "val"})
        expect(target[:args]).to eq []
      end

      it "raises an error when vars is not a Hash" do
        env = Environment.new
        expect { env.Program("a.out", "main.c", "other") }.to raise_error /Unexpected construction variable set/
      end
    end

    describe "#depends" do
      it "records the given dependencies in @user_deps" do
        env = Environment.new
        env.depends("foo", "bar", "baz")
        expect(env.instance_variable_get(:@user_deps)).to eq({"foo" => ["bar", "baz"]})
      end
      it "records user dependencies only once" do
        env = Environment.new
        env.instance_variable_set(:@user_deps, {"foo" => ["bar"]})
        env.depends("foo", "bar", "baz")
        expect(env.instance_variable_get(:@user_deps)).to eq({"foo" => ["bar", "baz"]})
      end
      it "expands arguments for construction variable references" do
        env = Environment.new
        env["foo"] = "foo.exe"
        env["bar"] = "bar.c"
        env.depends("${foo}", "${bar}", "a.h")
        expect(env.instance_variable_get(:@user_deps)).to eq({"foo.exe" => ["bar.c", "a.h"]})
      end
    end

    describe "#build_sources" do
      class ABuilder < Builder
        def produces?(target, source, env)
          target =~ /\.ab_out$/ and source =~ /\.ab_in$/
        end
      end

      it "finds and invokes a builder to produce output files with the requested suffixes" do
        cache = "cache"
        env = Environment.new
        env.add_builder(ABuilder.new)
        expect(env.builders["Object"]).to receive(:run).with("mod.o", ["mod.c"], cache, env, anything).and_return("mod.o")
        expect(env.builders["ABuilder"]).to receive(:run).with("mod2.ab_out", ["mod2.ab_in"], cache, env, anything).and_return("mod2.ab_out")
        expect(env.build_sources(["precompiled.o", "mod.c", "mod2.ab_in"], [".o", ".ab_out"], cache, {})).to eq ["precompiled.o", "mod.o", "mod2.ab_out"]
      end
    end

    describe "#run_builder" do
      it "modifies the construction variables using given build hooks and invokes the builder" do
        env = Environment.new
        env.add_build_hook do |build_op|
          if build_op[:sources].first =~ %r{src/special}
            build_op[:vars]["CFLAGS"] += ["-O3", "-DSPECIAL"]
          end
        end
        allow(env.builders["Object"]).to receive(:run) do |target, sources, cache, env, vars|
          expect(vars["CFLAGS"]).to eq []
        end
        env.run_builder(env.builders["Object"], "build/normal/module.o", ["src/normal/module.c"], "cache", {})
        allow(env.builders["Object"]).to receive(:run) do |target, sources, cache, env, vars|
          expect(vars["CFLAGS"]).to eq ["-O3", "-DSPECIAL"]
        end
        env.run_builder(env.builders["Object"], "build/special/module.o", ["src/special/module.c"], "cache", {})
      end
    end

    describe "#shell" do
      it "executes the given shell command and returns the results" do
        env = Environment.new
        expect(env.shell("echo hello").strip).to eq("hello")
      end
      it "determines shell flag to be /c when SHELL is specified as 'cmd'" do
        env = Environment.new
        env["SHELL"] = "cmd"
        expect(IO).to receive(:popen).with(["cmd", "/c", "my_cmd"])
        env.shell("my_cmd")
      end
      it "determines shell flag to be -c when SHELL is specified as something else" do
        env = Environment.new
        env["SHELL"] = "my_shell"
        expect(IO).to receive(:popen).with(["my_shell", "-c", "my_cmd"])
        env.shell("my_cmd")
      end
    end

    describe "#parse_flags" do
      it "executes the shell command and parses the returned flags when the input argument begins with !" do
        env = Environment.new
        env["CFLAGS"] = ["-g"]
        expect(env).to receive(:shell).with("my_command").and_return(%[-arch my_arch -Done=two -include ii -isysroot sr -Iincdir -Llibdir -lmy_lib -mno-cygwin -mwindows -pthread -std=c99 -Wa,'asm,args 1 2' -Wl,linker,"args 1 2" -Wp,cpp,args,1,2 -arbitrary +other_arbitrary some_lib /a/b/c/lib])
        rv = env.parse_flags("!my_command")
        expect(rv).to eq({
          "CCFLAGS" => %w[-arch my_arch -include ii -isysroot sr -mno-cygwin -pthread -arbitrary +other_arbitrary],
          "LDFLAGS" => %w[-arch my_arch -isysroot sr -mno-cygwin -mwindows -pthread] + ["linker", "args 1 2"] + %w[+other_arbitrary],
          "CPPPATH" => %w[incdir],
          "LIBS" => %w[my_lib some_lib /a/b/c/lib],
          "LIBPATH" => %w[libdir],
          "CPPDEFINES" => %w[one=two],
          "CFLAGS" => %w[-std=c99],
          "ASFLAGS" => ["asm", "args 1 2"],
          "CPPFLAGS" => %w[cpp args 1 2],
        })
        expect(env["CFLAGS"]).to eq(["-g"])
        expect(env["ASFLAGS"]).to eq([])
        env.merge_flags(rv)
        expect(env["CFLAGS"]).to eq(["-g", "-std=c99"])
        expect(env["ASFLAGS"]).to eq(["asm", "args 1 2"])
      end
    end

    describe "#parse_flags!" do
      it "parses the given build flags and merges them into the Environment" do
        env = Environment.new
        env["CFLAGS"] = ["-g"]
        rv = env.parse_flags!("-I incdir -D my_define -L /a/libdir -l /some/lib")
        expect(rv).to eq({
          "CPPPATH" => %w[incdir],
          "LIBS" => %w[/some/lib],
          "LIBPATH" => %w[/a/libdir],
          "CPPDEFINES" => %w[my_define],
        })
        expect(env["CPPPATH"]).to eq(%w[incdir])
        expect(env["LIBS"]).to eq(%w[/some/lib])
        expect(env["LIBPATH"]).to eq(%w[/a/libdir])
        expect(env["CPPDEFINES"]).to eq(%w[my_define])
      end
    end

    describe "#merge_flags" do
      it "appends array contents and replaces other variable values" do
        env = Environment.new
        env["CPPPATH"] = ["incdir"]
        env["CSUFFIX"] = ".x"
        env.merge_flags("CPPPATH" => ["a"], "CSUFFIX" => ".c")
        expect(env["CPPPATH"]).to eq(%w[incdir a])
        expect(env["CSUFFIX"]).to eq(".c")
      end
    end

    describe ".parse_makefile_deps" do
      it 'handles dependencies on one line' do
        expect(File).to receive(:read).with('makefile').and_return(<<EOS)
module.o: source.cc
EOS
        expect(Environment.parse_makefile_deps('makefile', 'module.o')).to eq ['source.cc']
      end

      it 'handles dependencies split across many lines' do
        expect(File).to receive(:read).with('makefile').and_return(<<EOS)
module.o: module.c \\
  module.h \\
  other.h
EOS
        expect(Environment.parse_makefile_deps('makefile', 'module.o')).to eq [
          'module.c', 'module.h', 'other.h']
      end
    end
  end
end
