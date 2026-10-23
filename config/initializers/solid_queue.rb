# In production Solid Queue runs as threads inside Puma (solid_queue_mode :async in
# config/puma.rb). Unlike fork mode, the Puma plugin doesn't watch the supervisor
# in async mode: if its thread dies (e.g. Postgres drops while it's replacing a
# crashed worker), Puma keeps answering webhooks with 200 while nothing runs the
# jobs. Stop Puma instead, so Heroku restarts the dyno with a fresh supervisor.
#
# on_stop only runs on a deliberate stop (Puma shutting down or restarting), so an
# on_exit without it means the supervisor crashed.
supervisor_stopping = false

SolidQueue.on_start { supervisor_stopping = false }
SolidQueue.on_stop { supervisor_stopping = true }

SolidQueue.on_exit do |supervisor|
  next if supervisor.standalone? || supervisor_stopping

  Rails.logger.error "Solid Queue supervisor exited unexpectedly, stopping Puma so the dyno restarts"
  Process.kill(:INT, Process.pid)
end
