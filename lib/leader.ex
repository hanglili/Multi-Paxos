# Hang Li Li (hl4716)

defmodule Leader do
  def start(config) do
    receive do
      {:bind, acceptors, replicas} ->
        # Using the server_num as the leader id since that is unique to each leader.
        spawn(Scout, :start, [self(), acceptors, {0, config.server_num}, config])
        send(config.monitor, {:scout_spawned, config.server_num})
        next(acceptors, replicas, {0, config.server_num}, false, Map.new(), config)
    end
  end

  defp next(acceptors, replicas, ballot_num, active, proposals, config) do
    receive do
      {:propose, slot, command} ->
        # {x, y} = ballot_num
        # IO.puts("Proposed: the ballot_num is #{x}")
        if not Map.has_key?(proposals, slot) do
          proposals = Map.put(proposals, slot, command)

          if active do
            spawn(Commander, :start, [self(), acceptors, replicas,
                 {ballot_num, slot, command}, config])
            send(config.monitor, {:commander_spawned, config.server_num})
          end

          next(acceptors, replicas, ballot_num, active, proposals, config)
        else
          next(acceptors, replicas, ballot_num, active, proposals, config)
        end

      {:adopted, ballot_num, pvalues} ->
        # {x, y} = ballot_num
        # IO.puts("Adopted: the ballot_num is #{x}")
        proposals = update_proposals(proposals, pmax(pvalues))
        # time1 = :os.system_time(:microsecond)
        for {s, c} <- proposals do
          spawn(Commander, :start, [self(), acceptors, replicas,
               {ballot_num, s, c}, config])
          send(config.monitor, {:commander_spawned, config.server_num})
        end
        # time2 = :os.system_time(:microsecond) - time1
        # IO.puts "Time taken is #{time2}"
        next(acceptors, replicas, ballot_num, true, proposals, config)

      {:preempted, {round_num, _} = msg_ballot_num} ->
        # IO.puts("Has been preempted")
        if msg_ballot_num > ballot_num do
          ballot_num = {round_num + 1, config.server_num}
          # Sleep to prevent live lock.
          Process.sleep(:rand.uniform(10) * 100)
          # Process.sleep(Enum.random(500..1000))
          # Process.sleep(:rand.uniform(1000))
          spawn(Scout, :start, [self(), acceptors, ballot_num, config])
          send(config.monitor, {:scout_spawned, config.server_num})
          next(acceptors, replicas, ballot_num, false, proposals, config)
        else
          next(acceptors, replicas, ballot_num, active, proposals, config)
        end
    end
  end

  defp get_c_with_max_b(s_pvalues) do
    Enum.reduce(s_pvalues, {-1, -1}, fn {b, _, c}, {max_b, max_c} ->
      max({max_b, max_c}, {b, c})
    end)
  end

  defp pmax(pvalues) do
    Enum.group_by(pvalues, fn {_, s, _} -> s end)
    |> Enum.reduce(Map.new(), fn {s, s_pvalues}, acc ->
      {_, c_with_max_b} = get_c_with_max_b(s_pvalues)
      Map.put(acc, s, c_with_max_b)
    end)
  end

  defp update_proposals(proposals, max_proposals) do
    Map.merge(proposals, max_proposals)
  end
end
