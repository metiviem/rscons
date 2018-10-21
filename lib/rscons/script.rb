module Rscons

  # The Script class encapsulates the state of a build script. It also provides
  # the DSL for the build script to use.
  class Script

    # @return [String, nil]
    #   Project name.
    attr_accessor :project_name

    # @return [Boolean]
    #   Whether to autoconfigure if the user does not explicitly perform a
    #   configure operation before building (default: true).
    attr_accessor :autoconf

    # Construct a Script.
    def initialize
      @project_name = nil
      @autoconf = true
    end

    # Load a script from the specified file.
    #
    # @param path [String]
    #   File name of the rscons script to load.
    #
    # @return [void]
    def load(path)
      script_contents = File.read(path, mode: "rb")
      self.instance_eval(script_contents, path, 1)
    end

  end

end
