# Hang Li Li (hl4716)

defmodule Leader do

  def start(config) do
    receive do
      { :bind, acceptors, replicas } ->
        spawn(Scout, :start, [self(), acceptors, 0])
        next(acceptors, replicas, { 0, Map.get(config, :server_num) },
             false, MapSet.new())
    end
  end

  defp next(acceptors, replicas, ballot_num, active, proposals) do
    receive do
      { :propose, slot, command } ->
        if slot_is_in_proposals(slot, proposals) do
          proposals = MapSet.put(proposals, { slot, command })
          if active do
            spawn(Commander, :start, [self(), acceptors, replicas, { ballot_num, slot, command }])
          end
          next(acceptors, replicas, ballot_num, active, proposals)
        else
          next(acceptors, replicas, ballot_num, active, proposals)
        end

      { :adopted, ballot_num, pvalues } ->
        proposals = update_proposals(proposals, pmax(pvalues))
        for { s, c } <- proposals do
          spawn(Commander, :start, [self(), acceptors, replicas, { ballot_num, s, c }])
        end
        next(acceptors, replicas, ballot_num, true, proposals)

      { :preempted, { round_num, leader_id } = another_ballot_num } ->
        if (another_ballot_num > ballot_num) do
          ballot_num = { round_num + 1, leader_id }
          spawn(Scout, :start, [self(), acceptors, ballot_num])
          next(acceptors, replicas, ballot_num, false, proposals)
        else
          next(acceptors, replicas, ballot_num, active, proposals)
        end
      end
  end

  defp slot_is_in_proposals(slot, proposals) do
    Enum.reduce(proposals, false, fn({ s, _ }), acc ->
      acc || (s == slot)
    end)
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
    split_pvalues = Enum.group_by(pvalues, fn({ b, s, c }) -> s end)
    Enum.reduce(split_pvalues, MapSet.new(), fn({ s, s_pvalues }), acc ->
      { _, c_with_max_b } = get_c_with_max_b(s_pvalues)
      Enum.put(acc, { s, c_with_max_b })
    end)
  end

  defp update_proposals(proposals, max_pvalues) do
    MapSet.union(max_pvalues, Enum.reduce(proposals, MapSet.new(), fn({ s, c }), acc ->
      if (not slot_is_in_proposals(s, proposals)) do
        MapSet.put(acc, { s, c })
      else
        acc
      end
    end)
    )
  end

end
