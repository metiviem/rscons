module Rscons
  module Util
    class << self

      # Make a relative path corresponding to a possibly absolute one.
      #
      # @param path [String]
      #   Input path that is possibly absolute.
      #
      # @return [String]
      #   Relative path.
      def make_relative_path(path)
        if Rscons.absolute_path?(path)
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
