defmodule Load do

  def add(n, count), do: Load.Runner.add(n, count)
  def remove(n, count), do: Load.Runner.remove(n, count)
  def i, do: Load.Stats.get_stats()
  def stop, do: Load.Runner.stop()

end
