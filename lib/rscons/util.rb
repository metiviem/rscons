module Rscons
  module Util
    class << self

      # Return whether the given path is an absolute filesystem path.
      #
      # @param path [String] the path to examine.
      #
      # @return [Boolean] Whether the given path is an absolute filesystem path.
      def absolute_path?(path)
        if RUBY_PLATFORM =~ /mingw/
          path =~ %r{^(?:\w:)?[\\/]}
        else
          path.start_with?("/")
        end
      end

      # Make a relative path corresponding to a possibly absolute one.
      #
      # @param path [String]
      #   Input path that is possibly absolute.
      #
      # @return [String]
      #   Relative path.
      def make_relative_path(path)
        if absolute_path?(path)
          if path =~ %r{^(\w):(.*)$}
            "_#{$1}#{$2}"
          else
            "_#{path}"
          end
        else
          path
        end
      end

    end
  end
end
