# Hang Li Li (hl4716)

defmodule Leader do
  def start(config) do
    receive do
      {:bind, acceptors, replicas} ->
        # Using the server_num as the leader id since that is unique to each leader.
        spawn(Scout, :start, [self(), acceptors, {0, config.server_num}, config])
        send(config.monitor, {:scout_spawned, config.server_num})
        next(acceptors, replicas, {0, config.server_num}, false, Map.new(), config, 1)
    end
  end

  defp next(acceptors, replicas, ballot_num, active, proposals, config, timeout) do
    receive do
      {:propose, slot, command} ->
        if not Map.has_key?(proposals, slot) do
          proposals = Map.put(proposals, slot, command)

          if active do
            spawn(Commander, :start, [self(), acceptors, replicas,
                 {ballot_num, slot, command}, config])
            send(config.monitor, {:commander_spawned, config.server_num})
          end

          next(acceptors, replicas, ballot_num, active, proposals, config, timeout)
        else
          next(acceptors, replicas, ballot_num, active, proposals, config, timeout)
        end

      {:adopted, received_ballot_num, pvalues} ->
        if received_ballot_num == ballot_num do
          proposals = update_proposals(proposals, pmax(pvalues))
          for {s, c} <- proposals do
            spawn(Commander, :start, [self(), acceptors, replicas,
                 {ballot_num, s, c}, config])
            send(config.monitor, {:commander_spawned, config.server_num})
          end
          timeout = timeout - div(:rand.uniform(timeout), 2)
          next(acceptors, replicas, ballot_num, true, proposals, config, timeout)
        else
          next(acceptors, replicas, ballot_num, active, proposals, config, timeout)
        end

      {:preempted, {round_num, _} = msg_ballot_num} ->
        if msg_ballot_num > ballot_num do
          ballot_num = {round_num + 1, config.server_num}

          # Sleep to prevent livelock.
          timeout = timeout + :rand.uniform(timeout)
          # timeout = timeout + Enum.random(1..timeout)
          Process.sleep(timeout)
          spawn(Scout, :start, [self(), acceptors, ballot_num, config])
          send(config.monitor, {:scout_spawned, config.server_num})
          next(acceptors, replicas, ballot_num, false, proposals, config, timeout)
        else
          next(acceptors, replicas, ballot_num, active, proposals, config, timeout)
        end

      {:decrease_timeout} ->
        timeout = timeout - div(:rand.uniform(timeout), 2)
        next(acceptors, replicas, ballot_num, active, proposals, config, timeout)
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
