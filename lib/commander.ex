# Hang Li Li (hl4716)

defmodule Commander do

  def start(leader, acceptors, replicas, pvalue) do
    for acceptor <- acceptors do
      send acceptor, { :p2a, self(), pvalue }
    end
    next(leader, pvalue, acceptors, acceptors, replicas)
  end

  defp next(leader, { b, s, c } = pvalue, waitfor, acceptors, replicas) do
    IO.puts "<c.1>"
    receive do
      { :p2b, acceptor, acceptor_b } ->
        IO.puts "<c.2>"
        if (acceptor_b == b) do
          waitfor = MapSet.delete(waitfor, acceptor)
          if (MapSet.size(waitfor) < (MapSet.size(acceptors) / 2)) do
            for replica <- replicas do
              IO.puts "<c.3>"
              send replica, { :decision, s, c }
            end
            Process.exit(self(), "Finished its function")
          end
          next(leader, pvalue, waitfor, acceptors, replicas)
        else
          send leader, { :preempted, acceptor_b }
          Process.exit(self(), "Finished its function")
        end
      end
  end

end
