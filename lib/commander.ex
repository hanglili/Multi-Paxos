# Hang Li Li (hl4716)

defmodule Commander do
  def start(leader, acceptors, replicas, pvalue, config) do
    for acceptor <- acceptors do
      send(acceptor, {:p2a, self(), pvalue})
    end

    next(leader, pvalue, MapSet.new(acceptors), acceptors, replicas, config)
  end

  defp next(leader, {b, s, c} = pvalue, waitfor, acceptors, replicas, config) do
    receive do
      {:p2b, acceptor, acceptor_b} ->
        if acceptor_b == b do
          waitfor = MapSet.delete(waitfor, acceptor)
          # Note that / is float division in Elixir
          if MapSet.size(waitfor) < (length(acceptors) / 2) do
            for replica <- replicas do
              send(replica, {:decision, s, c})
            end

            send(config.monitor, {:commander_finished, config.server_num})
            Process.exit(self(), "Finished its function")
          end

          next(leader, pvalue, waitfor, acceptors, replicas, config)
        else
          send(leader, {:preempted, acceptor_b})
          send(config.monitor, {:commander_finished, config.server_num})
          Process.exit(self(), "Finished its function")
        end
    end
  end
end
