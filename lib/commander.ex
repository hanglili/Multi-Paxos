# Hang Li Li (hl4716)

defmodule Commander do

  def start(leader_id, acceptors, replicas, pvalue) do
    for acceptor <- acceptors do
      send acceptor, { :p2a, self(), pvalue }
    end
    next(leader_id, pvalue, acceptors, acceptors, replicas)
  end

  defp next(leader_id, { b, s, c }, waitfor, acceptors, replicas) do
    receive do
      { :p2b, acceptor_id, acceptor_b } ->
        if (acceptor_b == b) do
          waitfor = MapSet.delete(waitfor, acceptor_id)
          if (MapSet.size(waitfor) < (MapSet.size(acceptors) / 2)) do
            for replica <- replicas do
              send replica, { :decision, s, c }
            end
            Process.exit(self(), "Finished its function")
          end
          next(leader_id, { b, s, c }, waitfor, acceptors, replicas)
        else
          send leader_id, { :preempted, acceptor_b }
          Process.exit(self(), "Finished its function")
        end
      end
  end

end
