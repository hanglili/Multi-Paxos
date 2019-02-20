# Hang Li Li (hl4716)

defmodule Leader do

  def start(config) do
    receive do
      { :bind, acceptors, replicas } ->
        spawn(Scout, :start, [self(), acceptors, { 0, config.server_num} ])
        next(acceptors, replicas, { 0, Map.get(config, :server_num) },
             false, Map.new())
    end
  end

  defp next(acceptors, replicas, ballot_num, active, proposals) do
    receive do
      { :propose, slot, command } ->
        if not Map.has_key?(proposals, slot) do
          proposals = Map.put(proposals, slot, command)
          if active do
            spawn(Commander, :start, [self(), acceptors, replicas, { ballot_num, slot, command }])
          end
          next(acceptors, replicas, ballot_num, active, proposals)
        else
          next(acceptors, replicas, ballot_num, active, proposals)
        end

      { :adopted, ballot_num, pvalues } ->
        # IO.puts "<l.2> with proposals #{inspect proposals} and pvalues #{inspect pvalues}"
        proposals = update_proposals(proposals, pmax(pvalues))
        # IO.puts "<l.3> with proposals #{inspect proposals}"
        for { s, c } <- proposals do
          spawn(Commander, :start, [self(), acceptors, replicas, { ballot_num, s, c }])
        end
        next(acceptors, replicas, ballot_num, true, proposals)

      { :preempted, { round_num, leader_id } = another_ballot_num } ->
        if (another_ballot_num > ballot_num) do
          ballot_num = { round_num + 1, leader_id }
          Process.sleep(Enum.random 100 .. 1000)
          spawn(Scout, :start, [self(), acceptors, ballot_num])
          next(acceptors, replicas, ballot_num, false, proposals)
        else
          next(acceptors, replicas, ballot_num, active, proposals)
        end
      end
  end

  defp get_c_with_max_b(s_pvalues) do
    Enum.reduce(s_pvalues, { -1, -1 }, fn({ b, _, c }), { max_b, max_c } ->
      if (max_b < b) do
        { b, c }
      else
        { max_b, max_c }
      end
    end)
  end

  defp pmax(pvalues) do
    Enum.group_by(pvalues, fn({ b, s, c }) -> s end)
    |> Enum.reduce(Map.new(), fn({ s, s_pvalues }), acc ->
       { _, c_with_max_b } = get_c_with_max_b(s_pvalues)
       Map.put(acc, s, c_with_max_b)
       end)
  end

  defp update_proposals(proposals, max_proposals) do
    Map.merge(proposals, max_proposals)
  end

end
