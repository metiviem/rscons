module Rscons

  # The Script class encapsulates the state of a build script. It also provides
  # the DSL for the build script to use.
  class Script

    class << self

      # Load a script from the specified file.
      #
      # @param path [String]
      #   File name of the rscons script to load.
      #
      # @return [Script]
      #   The loaded script state.
      def load(path)
        script_contents = File.read(path, mode: "rb")
        script = Script.new
        script.instance_eval(script_contents, path, 1)
        script
      end

    end

  end

end
