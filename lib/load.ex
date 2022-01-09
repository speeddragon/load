defmodule Load do

  # def add(n, count), do: :load_runner.add(n, count)
  # def remove(n, count), do: :load_runner.remove(n, count)
  def i, do: Load.Stats.get_stats()
  # def stop, do: :load_runner.stop()

end
