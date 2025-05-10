# Fixes well known issue where semantic logger doesn't work with
# https://docs.honeybadger.io/guides/insights/integrations/ruby-and-rails/
# Re-open appenders after forking the worker, dispatcher, and scheduler processes
SolidQueue.on_worker_start { SemanticLogger.reopen }
SolidQueue.on_dispatcher_start { SemanticLogger.reopen }
SolidQueue.on_scheduler_start { SemanticLogger.reopen }
