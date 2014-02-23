require 'concurrent/future'

module Concurrent

  module Dataflow

    class AtomicCounter

      def initialize(init)
        @counter = init
        @mutex = Mutex.new
      end

      def decrement
        @mutex.synchronize do
          @counter -= 1
        end
      end

    end

    class DependencyCounter

      def initialize(count, &block)
        @counter = AtomicCounter.new(count)
        @block = block
      end

      def update(time, value, reason)
        if @counter.decrement == 0
          @block.call()
        end
      end

    end

    def self.dataflow(*inputs, &block)
      raise ArgumentError.new('no block given') unless block_given?
      raise ArgumentError.new('not all dependencies are Futures') unless inputs.all? { |input| input.is_a? Future }

      result = Concurrent::Future.new do
        values = inputs.map { |input| input.value }
        block.call(*values)
      end

      if inputs.empty?
        result.execute
      else
        counter = Dataflow::DependencyCounter.new(inputs.size) { result.execute }

        inputs.each do |input|
          input.add_observer counter
        end
      end

      result
    end

  end

  def self.dataflow(*inputs, &block)
    Dataflow::dataflow(*inputs, &block)
  end

end