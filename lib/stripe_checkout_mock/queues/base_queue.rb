module StripeCheckoutMock
  module Queues
    module BaseQueue
      def initialize
        @queue = []
      end

      def add(obj)
        @queue.push(obj)
      end

      def each(&block)
        @queue.reverse.each(&block)
      end

      def pop
        @queue.pop
      end
    end
  end
end
