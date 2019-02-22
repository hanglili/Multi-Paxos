# Hang Li Li (hl4716)

defmodule Scout do

  def start(leader, acceptors, b, config) do
    for acceptor <- acceptors do
      send(acceptor, {:p1a, self(), b})
    end

    next(leader, b, MapSet.new(acceptors), acceptors, MapSet.new(), config)
  end

  defp next(leader, b, waitfor, acceptors, pvalues, config) do
    receive do
      {:p1b, acceptor, acceptor_b, acceptor_pvalues} ->
        if acceptor_b == b do
          pvalues = MapSet.union(pvalues, acceptor_pvalues)
          waitfor = MapSet.delete(waitfor, acceptor)

          # Note that / is float division in Elixir
          if MapSet.size(waitfor) < (length(acceptors) / 2) do
            send(leader, {:adopted, b, pvalues})
            send(config.monitor, {:scout_finished, config.server_num})
            Process.exit(self(), "Finished its function")
          end

          next(leader, b, waitfor, acceptors, pvalues, config)
        else
          send(leader, {:preempted, acceptor_b})
          send(config.monitor, {:scout_finished, config.server_num})
          Process.exit(self(), "Finished its function")
        end
    end
  end

end
