# frozen_string_literal: true

# Debounced credloop runner.
# Runs after every transaction. If transactions come in faster than the
# detector runs, only queues one more run — never a backlog.
#
# Thread-safe: uses a mutex to protect the running/pending state.

class CredloopRunner
  class << self
    def instance
      @instance ||= new
    end

    delegate :trigger, to: :instance
  end

  def initialize
    @mutex = Mutex.new
    @running = false
    @pending = false
  end

  # Called after every transaction. Runs the detector if not already running.
  # If already running, flags one more run when done.
  def trigger(network)
    @mutex.synchronize do
      if @running
        @pending = true
        Rails.logger.debug("[CredloopRunner] Already running, queued one more")
        return
      end
      @running = true
    end

    Thread.new do
      run_loop(network)
    end
  end

  private

  def run_loop(network)
    loop do
      begin
        cancelled = CredloopService.cancel_all_loops(network)
        if cancelled.any?
          Rails.logger.info("[CredloopRunner] Cancelled #{cancelled.size} loops")
        end
      rescue => e
        Rails.logger.warn("[CredloopRunner] Error: #{e.message}")
      end

      @mutex.synchronize do
        if @pending
          @pending = false
          # Loop again — one more run was requested
        else
          @running = false
          return
        end
      end
    end
  end
end
