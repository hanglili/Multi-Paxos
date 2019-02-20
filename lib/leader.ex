# Hang Li Li (hl4716)

defmodule Leader do
  def start(config) do
    receive do
      {:bind, acceptors, replicas} ->
        # Using the server_num as the leader id since that is unique to each leader.
        spawn(Scout, :start, [self(), acceptors, {0, config.server_num}])
        next(acceptors, replicas, {0, config.server_num}, false, Map.new(), config)
    end
  end

  defp next(acceptors, replicas, ballot_num, active, proposals, config) do
    receive do
      {:propose, slot, command} ->
        if not Map.has_key?(proposals, slot) do
          proposals = Map.put(proposals, slot, command)

          if active do
            spawn(Commander, :start, [self(), acceptors, replicas, {ballot_num, slot, command}])
          end

          next(acceptors, replicas, ballot_num, active, proposals, config)
        else
          next(acceptors, replicas, ballot_num, active, proposals, config)
        end

      {:adopted, ballot_num, pvalues} ->
        proposals = update_proposals(proposals, pmax(pvalues))

        for {s, c} <- proposals do
          spawn(Commander, :start, [self(), acceptors, replicas, {ballot_num, s, c}])
        end

        next(acceptors, replicas, ballot_num, true, proposals, config)

      {:preempted, {round_num, _} = msg_ballot_num} ->
        if msg_ballot_num > ballot_num do
          ballot_num = {round_num + 1, config.server_num}
          Process.sleep(:rand.uniform(10) * 100)
          spawn(Scout, :start, [self(), acceptors, ballot_num])
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
