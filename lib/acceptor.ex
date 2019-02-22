# Hang Li Li (hl4716)

defmodule Acceptor do

  def start(_) do
    # {-1, -1} is used to denote the initial smallest ballot number
    next({-1, -1}, MapSet.new())
  end

  defp next(ballot_num, accepted) do
    receive do
      {:p1a, leader, b} ->
        ballot_num = max(b, ballot_num)
        send(leader, {:p1b, self(), ballot_num, accepted})
        next(ballot_num, accepted)

      {:p2a, leader, pvalue} ->
        accepted = update_accepted(accepted, ballot_num, pvalue)
        send(leader, {:p2b, self(), ballot_num})
        next(ballot_num, accepted)
    end
  end

  defp update_accepted(accepted, ballot_num, {b, _, _} = pvalue) do
    if b == ballot_num do
      MapSet.put(accepted, pvalue)
    else
      accepted
    end
  end

end
