ExUnit.start()

# Явно подгружаем support-модули
Code.require_file("support/memory_sink.exs", __DIR__)

# Подменяем sink на MemorySink для всех тестов
Application.put_env(:lab3, :sink, Test.MemorySink)
