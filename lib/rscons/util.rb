module Rscons
  # A collection of stand-alone utility methods.
  module Util
    class << self

      # Wait for any of a number of threads to complete.
      #
      # @param threads [Array<Thread>]
      #   Threads to wait for.
      #
      # @return [Thread]
      #   The Thread that completed.
      def wait_for_thread(*threads)
        if threads.empty?
          raise "No threads to wait for"
        end
        queue = Queue.new
        threads.each do |thread|
          # Create a wait thread for each thread we're waiting for.
          Thread.new do
            begin
              thread.join
            ensure
              queue.push(thread)
            end
          end
        end
        # Wait for any thread to complete.
        queue.pop
      end

    end
  end
end
