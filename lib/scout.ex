# Hang Li Li (hl4716)

defmodule Scout do

  def start(leader, acceptors, b) do
    for acceptor <- acceptors do
      send acceptor, { :p1a, self(), b }
    end
    next(leader, b, MapSet.new(acceptors), acceptors, MapSet.new())
  end

  defp next(leader, b, waitfor, acceptors, pvalues) do
    receive do
      { :p1b, acceptor, acceptor_b, acceptor_pvalues } ->
        if (acceptor_b == b) do
          pvalues = MapSet.union(pvalues, acceptor_pvalues)
          waitfor = MapSet.delete(waitfor, acceptor)
          if (MapSet.size(waitfor) < (length(acceptors) / 2)) do
            send leader, { :adopted, b, pvalues }
            Process.exit(self(), "Finished its function")
          end
          next(leader, b, waitfor, acceptors, pvalues)
        else
          send leader, { :preempted, acceptor_b }
          Process.exit(self(), "Finished its function")
        end
      end
  end

end
