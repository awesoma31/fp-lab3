ExUnit.start()

Code.require_file("support/memory_sink.exs", __DIR__)

Application.put_env(:lab3, :sink, Test.MemorySink)
